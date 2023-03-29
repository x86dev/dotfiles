#!/usr/bin/env python
# -*- coding: utf-8 -*-

# pylint: disable=global-statement
# pylint: disable=missing-function-docstring

"""
Tries to remove file duplicates and unwanted stuff.
"""

from collections import namedtuple # Requires at least Python 2.6.
import datetime
import getopt
import math
import os
import re # Regular expressions.
import shutil # For rmtree().
import sys

g_fDryRun        = True
g_cDupesTotal    = 0
g_cbDupesTotal   = 0
g_cbDupesRemoved = 0
g_sLogFile       = ''
g_fRecursive     = False
g_fDeleteSimilar = False
g_cVerbosity     = 0

tFileDupe = namedtuple('tFileDupe', 'ext, prio')

g_aVideoTypes = [ tFileDupe('mkv' , 0),
                  tFileDupe('avi' , 10),
                  tFileDupe('mp4' , 20),
                  tFileDupe('divx', 30),
                  tFileDupe('wmv' , 50) ]

# Minimum size a video file must have (in bytes).
# This is useful for not treating a video file as the newest (=best) file
# if this file is just e.g. a sample / demo file.
#
# Set to 0 to disable this check.
g_cbVideoSizeMin = 700 * (1024 * 1024) ## @todo Use a constant for MB as bytes?

# Array of regular expressions to detect directories to delete. BE CAUTIOUS HERE!
g_aRegExDirsToDelete = [ '.*/_UNPACK_*' ]

# Array of regular expressions to use detecting similar release directories.
g_aRegExDirsSimilar = [ '.*[\.| +][0-9][0-9][0-9][0-9][\.| +].*' ]

g_aFileExtsToDelete = [ 'url', 'nzb', 'exe', 'com', 'bat', 'cmd', 'sample', 'scr', 'rar', 'zip', '7z' ]

# Taken from: http://stackoverflow.com/questions/5194057/better-way-to-convert-file-sizes-in-python
# Slightly modified to handle byte sizes as well.
def fileSizeToStr(size):
    if size:
        size_name = ("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
        i = int(math.floor(math.log(size,1024)))
        p = math.pow(1024,i)
        s = round(size/p,2)
        if s > 0:
            return '%s %s' % (s,size_name[i])
    return '0B'

def getModTime(sPath):
    mTime = os.path.getmtime(sPath)
    return datetime.datetime.fromtimestamp(mTime)

def deleteFile(sFile):
    print("\tDeleting file: %s" % sFile)
    if g_fDryRun:
        return
    try:
        os.remove(sFile)
    except OSError as e:
        print("\tError deleting file \"%s\": %s" % (sFile, str(e)))

def deleteDir(sDir, fRecursive):
    print("\tDeleting directory: %s" % sDir)
    if g_fDryRun:
        return
    try:
        if fRecursive:
            shutil.rmtree(sDir, ignore_errors = False)
        else:
            os.rmdir(sDir)
    except OSError as e:
        print("\tError deleting directory \"%s\": %s" % (sDir, str(e)))

def fileIsMultipart(sDir, sFile):
    _ = sDir
    _ = sFile

def cleanupDupes(sDir, fRecursive):
    global g_cDupesTotal
    global g_cbDupesTotal
    if g_cVerbosity:
        print("Handling directory \"%s\"" % (sDir))
    for sCurDir, aSubDirs, aFiles in os.walk(sDir):
        if g_fRecursive:
            if g_fDeleteSimilar:
                aDirSimilar    = [] # Contains all similar releases.
                sDirSimilarCur = '' # Name of the current similar directory prefix to handle.
                # Note: This ASSUMES that the directory output is alphabetically sorted!
                for sSubDir in sorted(aSubDirs):
                    sSubDirAbs = os.path.join(sDir, sSubDir)
                    for sRegEx in g_aRegExDirsSimilar:
                        rec = re.compile(r"(\b(.*)\b)" + sRegEx)
                        res = re.search(rec, sSubDirAbs)
                        if res:
                            if not sDirSimilarCur or sDirSimilarCur != res.group(1):
                                aDirSimilar = []
                                sDirSimilarCur = res.group(1)
                            if res.group(1) == sDirSimilarCur:
                                aDirSimilar.append(sSubDirAbs)

                if aDirSimilar:
                    if g_cVerbosity:
                        print("Found %d similar directories of \"%s\"" % (len(aDirSimilar), sDirSimilarCur))
                    tsDirNewest = datetime.datetime(1970, 1, 1)
                    sDirNewest  = ''
                    for sCurSimDir in aDirSimilar:
                        if g_cVerbosity:
                            print("Directory \"%s\" is similar" % (sCurSimDir))
                        tsDirLastMod = getModTime(sCurSimDir)
                        if tsDirLastMod > tsDirNewest:
                            tsDirNewest = tsDirLastMod
                            sDirNewest  = sCurSimDir
                    print("Directory \"%s\" is the newest one" % (sDirNewest))
                    for sCurSimDir in aDirSimilar:
                        if sCurSimDir == sDirNewest:
                            cleanupDupes(sCurSimDir, fRecursive)
                        else:
                            deleteDir(sCurSimDir, True)
                aDirSimilar = []
            else: # Do not delete delete similar dirs.
                for sSubDir in sorted(aSubDirs):
                    sSubDirAbs = os.path.join(sDir, sSubDir)
                    cleanupDupes(sSubDirAbs, fRecursive)
        mtimeDir = os.path.getmtime(sCurDir)
        arrDupes = []
        for sFile in aFiles:
            sFileAbs = os.path.join(sCurDir, sFile)
            sName, sExt = os.path.splitext(sFileAbs)
            sName = sName.lower()
            if len(sExt) > 1: # Skip the dot (.)
                sExt = sExt[1:]
            for curType in g_aVideoTypes:
                if curType.ext == sExt:
                    arrDupes.append(sFileAbs)
            for curExt in g_aFileExtsToDelete:
                if curExt == sExt:
                    print("File \"%s\" is junk" % sFileAbs)
                    deleteFile(sFileAbs)

        if len(arrDupes) >= 2:
            print("Directory \"%s\" contains %d entries:" % (sCurDir, len(arrDupes)))
            tsFileNewest = datetime.datetime(1970, 1, 1)
            sFileNewest  = ''
            for curDupe in arrDupes:
                tsFileLastMod = getModTime(curDupe)
                cbFileSize    = os.path.getsize(curDupe)
                print("\t%s (last modified %s, %s)" % (curDupe, tsFileLastMod, fileSizeToStr(cbFileSize)))
                if tsFileLastMod >  tsFileNewest \
                and cbFileSize   >= g_cbVideoSizeMin:
                    sFileNewest  = curDupe
                    tsFileNewest = tsFileLastMod
            if sFileNewest:
                print("\tNewest file: %s" % sFileNewest)
                for curDupe in arrDupes:
                    if      curDupe != sFileNewest \
                    and not fileIsMultipart(sCurDir, curDupe):
                        g_cDupesTotal  += 1
                        g_cbDupesTotal += os.path.getsize(curDupe)
                        deleteFile(curDupe)
            else:
                print("\tWarning: Unable to determine newest file!")

        # Delete unwanted junk.
        for sRegEx in g_aRegExDirsToDelete:
            if   re.compile(sRegEx).match(sCurDir) \
            and  sCurDir \
            and  sCurDir != "/":
                print("Directory \"%s\" is junk" % sCurDir)
                deleteDir(sCurDir, True)

        # Delete empty directories.
        if os.path.isdir(sCurDir) and len(os.listdir(sCurDir)) == 0:
            print("Directory \"%s\" is empty" % sCurDir)
            deleteDir(sCurDir, False)
            sCurDir = None

        # Re-apply directory modification time.
        if sCurDir:
            os.utime(sCurDir, (-1, mtimeDir))

        if not fRecursive:
            break

def printHelp():
    print("--delete")
    print("    Deletion mode: Files/directories *are* modified and/or deleted.")
    print("--help or -h")
    print("    Prints this help text.")
    print("--recursive or -R")
    print("    Also processes sub directories.")
    print("-v")
    print("    Increases logging verbosity. Can be specified multiple times.")
    print("\n")

def main():
    global g_fDryRun
    global g_fRecursive
    global g_fDeleteSimilar
    global g_cVerbosity

    if len(sys.argv) <= 1:
        print("Must specify a path!")
        sys.exit(2)

    try:
        aOpts, aArgs = getopt.gnu_getopt(sys.argv[1:], "hRv", ["delete", "delete-similar", "help", "recursive", "verbose" ])
    except getopt.error as msg:
        print(msg)
        print("For help use --help")
        sys.exit(2)

    for o, a in aOpts:
        if o in "--delete":
            g_fDryRun = False
        if o in "--delete-similar":
            g_fDeleteSimilar = True
        if o in ("-h", "--help"):
            printHelp()
            sys.exit(0)
        if o in ("-R", "--recursive"):
            g_fRecursive = True
        if o in ("-v", "--verbose"):
            g_cVerbosity += 1

    if len(aArgs) <= 0:
        print("No source directory specified!")
        sys.exit(2)

    today = datetime.datetime.today()
    print("Started: %02d/%02d/%02d %02d:%02d:%02d" % (today.year, today.month, today.day, today.hour, today.minute, today.second))

    if g_fDryRun:
        print("*** Dryrun mode -- no files/directories deleted! ***")

    for sDir in aArgs:
        print("Processing: %s" % sDir)
        cleanupDupes(sDir, g_fRecursive)

    print("Total dupes: %ld (%s)" % (g_cDupesTotal, fileSizeToStr(g_cbDupesTotal)))

    if g_fDryRun:
        print("*** Dryrun mode -- no files/directories deleted! ***")

if __name__ == "__main__":
    main()
