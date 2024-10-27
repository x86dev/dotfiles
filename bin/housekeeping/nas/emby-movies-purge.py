#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
Purges movies which are too old.
"""

import sys
import codecs
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
g_fDryRun        = True
g_cVerbosity     = 0
g_dbRatingMin    = 0.0
g_uWidthMin      = 0
g_uHeightMin     = 0
g_fRatingNone    = False
g_tdOlderThan    = datetime.timedelta(days=0)
g_sProvider      = ""

# Configuration
g_sHost = ""
g_sUsername = ""
g_sPassword = ""

def embyCleanup():
    """
    Does the actual cleanup by using the Emby API.
    """

    # Authenticate.
    post_url = g_sHost + "/Users/AuthenticateByName"
    post_header = {'content-type': 'application/json',
                'Authorization' : 'Emby Client="Android", Device="Generic", DeviceId="Custom", Version="1.0.0.0"'}

    post_data = {"Username": g_sUsername, "Pw": g_sPassword, "appName": "foo" }
    resp = requests.post(post_url, json=post_data, headers=post_header, timeout=30)

    if resp.ok:
        resp_data = resp.json()
        #print(resp_data)
        emby_user_id=resp_data['SessionInfo']['UserId']
        emby_access_token=resp_data['AccessToken']
    else:
        resp.raise_for_status()
        return

    # Construct new header containing the retrieved access token.
    get_header = {'content-type': 'application/json',
                'X-MediaBrowser-Token' : emby_access_token}

    # If a collection is specified, get its ID.
    if g_sCollection:
        get_url = g_sHost + "/Users/" + emby_user_id + "/Views"
        resp = requests.get(get_url, headers=get_header, timeout=30)

        if resp.ok:
            resp_data = resp.json()
            #print(json.dumps(resp_data, indent=4))
        else:
            resp.raise_for_status()
            return

        idCollection = None
        for view in resp_data['Items']:
            if view['Name'] == g_sCollection:
                idCollection = view['Id']
                break
        if not idCollection:
            print("Collection not found or invalid!")
            return

    # Retrieve all items
    get_url = g_sHost + "/Users/" + emby_user_id + "/Items?"
    if g_sCollection:
        get_url += "parentId=" + idCollection + "&"
    get_url += "Recursive=true&IncludeItemTypes=Movie&Fields=PremiereDate,CommunityRating,Width,Height"
    resp = requests.get(get_url, headers=get_header, timeout=30)
    if resp.ok:
        resp_data = resp.json()
        #print(resp_data)
    else:
        resp.raise_for_status()
        return

    cItemsPurged = 0
    cItemsProc   = 0
    cErrors      = 0

    tsNow = datetime.datetime.now()

    if g_sCollection:
        print("Processing collection \"%s\"" % (g_sCollection))

    for movie in resp_data['Items']:
        movie_name = movie.get('Name')
        movie_date_premiere = movie.get('PremiereDate')
        movie_rating = float(movie.get('CommunityRating', 0.0))
        movie_rating = round(movie_rating, 2)
        movie_width = 0
        movie_height = 0
        v = movie.get('Width')
        if v:
            movie_width = int(v)

        v = movie.get('Height')
        if v:
            movie_height = int(v)

        sItem = "Processing '%s' ...\n" % (movie_name)

        # Don't delete any items by default.
        fDelete = False

        # Whether to use the provider lookup or not.
        fUseProvider = False

        if g_uWidthMin > 0 \
        and movie_width < g_uWidthMin:
            sItem = sItem + ("\tHas lower width resolution (%d)\n" % (movie_width,))
            fDelete = True

        if g_uHeightMin > 0 \
        and movie_height < g_uHeightMin:
            sItem = sItem + ("\tHas lower height resolution (%d)\n" % (movie_height,))
            fDelete = True

        if  g_fRatingNone is True \
        and movie_rating == 0.0:
            fUseProvider = True

        if  g_tdOlderThan.days > 0 \
        and movie_date_premiere is None:
            fUseProvider = True

        if fUseProvider:
            # Do we want to query OMDB for a rating?
            if g_sProvider == 'omdb':
                url = "http://www.omdbapi.com/?t=" + urllib.parse.quote(movie.get('Name'))
                resp = requests.get(url, timeout=30)
                if resp.ok:
                    omdb = json.loads(resp.text)
                    if omdb.get('Response') == 'True':
                        movie_rating = float(omdb.get('imdbRating', 0.0))
                        if g_cVerbosity >= 2:
                            sItem = sItem + ("\tOMDB rating = %f\n" % (movie_rating))
                        movie_date_premiere = omdb.get('Released')
                        if g_cVerbosity >= 2:
                            sItem = sItem + ("\tOMDB release date = %s\n" % (movie_date_premiere))

                    # Still no rating found?
                    if movie_rating == 0.0:
                        sItem = sItem + ("\tNo OMDB movie rating found!\n")
                        fDelete = True

        if g_tdOlderThan.days > 0:
            if movie_date_premiere:
                tsPremiere = datetime.datetime.strptime(movie_date_premiere[:19], '%Y-%m-%dT%H:%M:%S')
                tdAge      = tsNow - tsPremiere
                if tdAge.days > g_tdOlderThan.days:
                    sItem = sItem + ("\tToo old (%s days)\n" % tdAge.days)
                    fDelete = True
            else:
                sItem = sItem + ("\tWarning: No premiere date found!\n")

        if  g_fRatingNone is True \
        and movie_rating == 0.0:
            sItem = sItem + ("\tNo rating found\n")
            fDelete = True

        if  g_dbRatingMin > 0.0 \
        and movie_rating > 0.0  \
        and movie_rating < g_dbRatingMin:
            sItem = sItem + ("\tHas a lower rating (%f)\n" % movie_rating)
            fDelete = True

        if fDelete or g_cVerbosity >= 1:
            sys.stdout.write(sItem)
            sys.stdout.flush()

        if fDelete:
            print("\tDeleting ...")
            if g_fDryRun is False:
                movie_id = movie.get('Id')
                if movie_id is not None:
                    get_url = g_sHost + "/Items/" + movie_id
                    resp = requests.delete(get_url, headers=get_header, timeout=30)
                    if resp.ok:
                        print("\tSucessfully deleted")
                    else:
                        try:
                            cErrors += 1
                            resp.raise_for_status()
                        except resp.HTTPError:
                            pass
                else:
                    print("\tID for item not found")
                    cErrors += 1

            cItemsPurged += 1

        cItemsProc += 1

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
            [ "collection=", "delete", "help", "older-than-days=", "password=", \
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
