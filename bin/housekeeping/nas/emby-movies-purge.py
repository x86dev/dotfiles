#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Purges items from Emby.
See syntax help for options and usage.
"""

import sys
import codecs
from collections import defaultdict
import datetime
import json
import getopt
import urllib.parse
import requests

# pylint: disable=C0301
# pylint: disable=global-statement
# pylint: disable=invalid-name
# pylint: disable=consider-using-f-string

g_sCollection    = None
g_fDuplicates    = False
g_fNoMetadata    = False
g_fDeleteUnrated = False
g_fDryRun        = True
g_cVerbosity     = 0
g_dbRatingMin    = 0.0
g_uWidthMin      = 0
g_uHeightMin     = 0
g_fRatingNone    = False
g_tdOlderThan    = datetime.timedelta(days=0)
g_sProvider      = ""

# Emby state
g_EmbyUserId = None
g_EmbyAPIKey = None

# Configuration
g_sHost = ""
g_sUsername = ""
g_sPassword = ""

def login():
    url = f'{g_sHost}/Users/AuthenticateByName'
    headers = {
        'content-type': 'application/json',
        'Authorization' : 'Emby Client="Android", Device="Generic", DeviceId="Custom", Version="1.0.0.0"'
    }
    params = {
        'Username': g_sUsername,
        'Pw': g_sPassword,
        'appName': "foo"
    }
    resp = requests.post(url, headers=headers, json=params, timeout=30)
    resp_data = resp.json()
    global g_EmbyUserId
    g_EmbyUserId=resp_data['SessionInfo']['UserId']
    global g_EmbyAPIKey
    g_EmbyAPIKey=resp_data['AccessToken']
    return True

# Get all collections from Jellyfin
def get_collections():
    url = f'{g_sHost}/Users/{g_EmbyUserId}/Views'
    headers = {
        'X-Emby-Token': g_EmbyAPIKey
    }
    params = {
        'IncludeItemTypes': 'BoxSet',
        'Recursive': 'true'
    }
    params = None
    response = requests.get(url, headers=headers, params=params, timeout=30)
    response.raise_for_status()
    return response.json()['Items']

# Get collection ID by name
def get_collection_id_by_name(collections, name):
    for collection in collections:
        if collection['Name'].lower() == name.lower():
            return collection['Id']
    return None

def get_items(collection_id=None):
    url = f'{g_sHost}/Users/{g_EmbyUserId}/Items'
    headers = {
        'X-Emby-Token': g_EmbyAPIKey
    }
    params = {
        'IncludeItemTypes': 'Movie',
        'Fields' : 'DateCreated,Overview,PremiereDate,CommunityRating,Width,Height',
        'Recursive': 'true'
    }
    if collection_id:
        params['ParentId'] = collection_id
    response = requests.get(url, headers=headers, params=params, timeout=30)
    response.raise_for_status()
    return response.json()['Items']

# Delete an item by ID
def delete_item(item_id):
    if g_fDryRun is False:
        url = f'{g_sHost}/Items/{item_id}'
        headers = {
            'X-Emby-Token': g_EmbyAPIKey
        }
        resp = requests.delete(url, headers=headers, timeout=30)
        if resp.ok:
            return True
        else:
            try:
                resp.raise_for_status()
            except resp.HTTPError:
                pass
        return False
    return True

# Detect duplicate items by title and year
def detect_duplicates(items):
    duplicates = defaultdict(list)
    for cur_item in items:
        title = cur_item['Name']
        year = cur_item.get('ProductionYear')
        key = f'{title} ({year})' if year else title
        duplicates[key].append(cur_item)

    return {key: items for key, items in duplicates.items() if len(items) > 1}

def embyCleanup():
    """
    Does the actual cleanup by using the Emby API.
    """

    if not login():
        return False

    # If a collection is specified, get its ID.
    coll_id = None
    if g_sCollection:
        coll = get_collections()
        if coll:
            coll_id = get_collection_id_by_name(coll, g_sCollection)
            if not coll_id:
                print(f"No collection found with the name: {g_sCollection}")
                return False

    items = get_items(coll_id)
    if not items:
        print("Error retrieving items")
        return False

    cItemsPurged = 0
    cItemsProc   = 0
    cErrors      = 0

    tsNow = datetime.datetime.now()

    if g_sCollection:
        print("Processing collection \"%s\"" % (g_sCollection))

    for cur_item in items:
        item_name = cur_item.get('Name')
        item_date_premiere = cur_item.get('PremiereDate')
        item_rating = float(cur_item.get('CommunityRating', 0.0))
        item_rating = round(item_rating, 2)
        item_width = 0
        item_height = 0
        v = cur_item.get('Width')
        if v:
            item_width = int(v)

        v = cur_item.get('Height')
        if v:
            item_height = int(v)

        sItem = "Processing '%s' ...\n" % (item_name)

        # Don't delete any items by default.
        fDelete = False

        # Whether to use the provider lookup or not.
        fUseProvider = False

        if g_uWidthMin > 0 \
        and item_width < g_uWidthMin:
            sItem = sItem + ("\tHas lower width resolution (%d)\n" % (item_width,))
            fDelete = True

        if g_uHeightMin > 0 \
        and item_height < g_uHeightMin:
            sItem = sItem + ("\tHas lower height resolution (%d)\n" % (item_height,))
            fDelete = True

        if  g_fRatingNone is True \
        and item_rating == 0.0:
            fUseProvider = True

        if  g_tdOlderThan.days > 0 \
        and item_date_premiere is None:
            fUseProvider = True

        if fUseProvider:
            # Do we want to query OMDB for a rating?
            if g_sProvider == 'omdb':
                url = "http://www.omdbapi.com/?t=" + urllib.parse.quote(cur_item.get('Name'))
                resp = requests.get(url, timeout=30)
                if resp.ok:
                    omdb = json.loads(resp.text)
                    if omdb.get('Response') == 'True':
                        item_rating = float(omdb.get('imdbRating', 0.0))
                        if g_cVerbosity >= 2:
                            sItem = sItem + ("\tOMDB rating = %f\n" % (item_rating))
                        item_date_premiere = omdb.get('Released')
                        if g_cVerbosity >= 2:
                            sItem = sItem + ("\tOMDB release date = %s\n" % (item_date_premiere))

                    # Still no rating found?
                    if item_rating == 0.0:
                        sItem = sItem + ("\tNo OMDB movie rating found!\n")
                        fDelete = True

        if g_tdOlderThan.days > 0:
            if item_date_premiere:
                tsPremiere = datetime.datetime.strptime(item_date_premiere[:19], '%Y-%m-%dT%H:%M:%S')
                tdAge      = tsNow - tsPremiere
                if tdAge.days > g_tdOlderThan.days:
                    sItem = sItem + ("\tToo old (%s days)\n" % tdAge.days)
                    fDelete = True
            else:
                sItem = sItem + ("\tWarning: No premiere date found!\n")

        if  g_fRatingNone is True \
        and item_rating == 0.0:
            sItem = sItem + ("\tNo rating found\n")
            fDelete = True

        if  g_dbRatingMin > 0.0 \
        and item_rating > 0.0  \
        and item_rating < g_dbRatingMin:
            sItem = sItem + ("\tHas a lower rating (%f)\n" % item_rating)
            fDelete = True

        if fDelete or g_cVerbosity >= 1:
            sys.stdout.write(sItem)
            sys.stdout.flush()

        if fDelete:
            print("\tDeleting ...")
            if g_fDryRun is False:
                item_id = cur_item.get('Id')
                if item_id is not None:
                    if not delete_item(item_id):
                        cErrors += 1

            cItemsPurged += 1

        cItemsProc += 1

    # Refresh list
    items = get_items(coll_id)

    # Process duplicates
    if g_fDuplicates:
        duplicates = detect_duplicates(items)
        if duplicates:
            print("Duplicate emtries detected:")
            for _, items in duplicates.items():
                # Sort items by DateCreated to keep the newest entry
                items.sort(key=lambda x: x['DateCreated'], reverse=True)
                print(f"Keeping: {items[0]['Name']} (Added: {items[0]['DateCreated']})")
                for cur_item in items[1:]:  # Skip the newest entry
                    print(f"Deleting {cur_item['Name']} (Added: {cur_item['DateCreated']})")
                    delete_item(cur_item['Id'])
                    cItemsPurged += 1
        else:
            print("No duplicate entries found.")

    # Delete items with no metadata
    if g_fNoMetadata:
        print("Searching for items with no metadata ...")
        for cur_item in items:
            if not cur_item.get('Overview'):
                print(f"Deleting {cur_item['Name']}")
                delete_item(cur_item['Id'])
                cItemsPurged += 1

    if cErrors:
        print("Warning: %ld errors occurred" % cErrors)
    print("Deleted %ld / %ld items" % (cItemsPurged, cItemsProc))

def printHelp():
    """
    Prints syntax help.
    """
    print("--collection <name>")
    print("    Specifies the collection to process.")
    print("--delete")
    print("    Deletion mode: Items *are* removed.")
    print("--delete-duplicates")
    print("    Deletes duplicate items.")
    print("--delete-unknown")
    print("    Deletes items with no meta data.")
    print("--help or -h")
    print("    Prints this help text.")
    print("--host <http://host:port>")
    print("    Hostname to connect to.")
    print("--older-than-days <days>")
    print("    Selects items which are older than the specified days since its premiere.")
    print("--password <password>")
    print("    Password to authenticate with.")
    print("--provider <type>")
    print("    Provider to use for information lookup.")
    print("    Currently only 'omdb' supported.")
    print("--rating-min <number>")
    print("    Selects items which have a lower rating than specified.")
    print("--rating-none")
    print("    Selects items which don't have a rating (yet).")
    print("--username <name>")
    print("    User name to authenticate with.")
    print("-v")
    print("    Increases logging verbosity. Can be specified multiple times.")
    print("\n")

def main():
    """
    Main function.
    """
    global g_sCollection
    global g_fDuplicates
    global g_fNoMetadata
    global g_fDryRun
    global g_cVerbosity
    global g_dbRatingMin
    global g_uWidthMin
    global g_uHeightMin
    global g_fRatingNone
    global g_tdOlderThan
    global g_sProvider

    global g_sHost
    global g_sUsername
    global g_sPassword

    # For output of unicode strings. Can happen with some movie titles.
    sys.stdout = codecs.getwriter('utf8')(sys.stdout.detach())
    sys.stderr = codecs.getwriter('utf8')(sys.stderr.detach())

    try:
        aOpts, aArgs = getopt.gnu_getopt(sys.argv[1:], "hv", \
            [ "collection=", "delete", "duplicates", "no-meta-data", "help", "older-than-days=", "password=", \
              "rating-min=", "rating-none", "width-min=", "height-min=", "username=", "provider=" ])
    except getopt.error as msg:
        print(msg)
        print("For help use --help")
        sys.exit(2)

    for o, a in aOpts:
        if o in "--collection":
            g_sCollection = a
        elif o in "--delete":
            g_fDryRun = False
        elif o in "--duplicates":
            g_fDuplicates = True
        elif o in "--no-meta-data":
            g_fNoMetadata = True
        elif o in ("-h", "--help"):
            printHelp()
            sys.exit(0)
        elif o in "--older-than-days":
            g_tdOlderThan = datetime.timedelta(days=int(a))
        elif o in "--password":
            g_sPassword = a
        elif o in "--provider":
            g_sProvider = a
        elif o in "--rating-none":
            g_fRatingNone = True
        elif o in "--rating-min":
            g_dbRatingMin = float(a)
        elif o in "--width-min":
            g_uWidthMin = int(a)
        elif o in "--height-min":
            g_uHeightMin = int(a)
        elif o in "--username":
            g_sUsername = a
        elif o in "-v":
            g_cVerbosity += 1
        else:
            assert False, "Unhandled option"

    # Do the argument checking after the options parsing so that
    # we can handle commands like "--help" and friends.
    if len(aArgs) < 1:
        print("No host specified, e.g. http://<ip>:<port>\n")
        print("Usually Emby runs on port 8096 (http) or 8920 (https).\n\n")
        sys.exit(1)

    g_sHost = aArgs[0]

    if not g_sUsername:
        print("No username specified\n")
        sys.exit(1)

    if  g_fRatingNone is False \
    and g_dbRatingMin <= 0.0 \
    and g_tdOlderThan == 0:
        print("Must specify --rating-min and/or no --rating-none\n")
        sys.exit(1)

    today = datetime.datetime.today()
    print("Started: %02d/%02d/%02d %02d:%02d:%02d" % (today.year, today.month, today.day, today.hour, today.minute, today.second))

    if g_cVerbosity:
        if  g_dbRatingMin > 0.0:
            print("Selecting: All items with a rating < %.1f" % (g_dbRatingMin))
        if  g_fRatingNone:
            print("Selecting: All items which don't have a rating (yet)")

    if g_fDryRun:
        print("*** Dryrun mode -- no items changed! ***")

    print("Connecting to: %s" % (g_sHost))

    embyCleanup()

    print("Cleanup done.")

    if g_fDryRun:
        print("*** Dryrun mode -- no items changed! ***")

if __name__ == "__main__":
    main()
