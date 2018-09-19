#!/bin/bash
# This script is supposed to be executed after each recording,
# from TVHeadend, as the post-processor command.
# .
# The script expects one parameter: the only parameter ($1) should point
# to the source file with the full path (i.e. /home/pi/rec/foobar.mkv).
# This can be easily passed from TVHeadend's internal variable system.
# (e.g. TVHeadend post-proc syntax: /home/pi/utilities/rec_copy.sh "%f")
# .
# There are prerequisites. Please check that the target folder has
# write premissions for all users. Also, please check the permissions for
# all users in the script directory (for logging) and the rescue directory
# (in case the copying to target directory fails). Also, ssmtp and mailutils
# need to be installed for the mail notification to work, please test that
# emailing works beforehand. Email is only sent if the process fails because
# of target folder problems os copying mismatch, other variables should be
# tested in advance.

# Set up the directory (without the last slash) in which the script (and the log) is (please check the permissions).
scriptdir="/home/scripts"

# Set up the target directory (without the last slash) (please check that it is 1) a valid folder/mount 2) with permissions).
targetdir="/media/targetdir"

# Set up a rescue directory (without the last slash), in case the copying to the actual target folder fails (please check the permissions).
rescuedir="/home/user/rescuedir"

# Set up the receiver that will get the failure notice (a valid email address).
emailtarget="xyz@domain.org"

# No need to edit the lines below this point, do not touch!

# Check that the script directory is valid.
if [ -d "$scriptdir" ]
then
    # This is the expected and not-logged condition.
    echo "The script directory seems to exist (permissions presumed), continuing."
else
    echo "The script directory is not set or it is not valid, exiting... (no log was created)"
    sleep 2
    exit 0
fi

# Script initiation logging.
curdatetime=$(date +"%d/%m/%Y %R")
echo "$curdatetime : Executing the rec-file copying script." >> "$scriptdir/log_rec_copy.txt"

# Check that the rescue directory is valid.
if [ -d "$rescuedir" ]
then
    # This is the expected and not-logged condition.
    echo "The rescue directory exists, continuing."
else
    echo "The rescue directory is not set or it is not valid, exiting..."
    sleep 2
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : The rescue directory is not set or is not valid, exiting." >> "$scriptdir/log_rec_copy.txt"
    exit 0
fi

# Copy the external parameter to something more readable.
filefull="$1"
filebase=$(basename "$filefull")

# Check that there is a valid source file to copy.
if [ -f "$filefull" ]
then
    # This is the expected and not-logged condition.
    echo "The source seems to be a valid file, continuing."
else
    echo "The source is not set or it is not a valid file, exiting..."
    sleep 2
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : The source file was not set or it is not a valid file, exiting." >> "$scriptdir/log_rec_copy.txt"
    exit 0
fi

# Next, the write-read-accessibility of the target folder is tested
# by creating a probe file. A numeric value is then written and then
# the value is read to a variable. If the variable matches the expected
# value, the target folder is considered valid. The probe file is deleted
# immediately after the the value is read.

# First, delete the unlikely pre-existing probe file.
if [ -f "$targetdir"/targetdirwritereadtest.txt ]
then
    rm "$targetdir"/targetdirwritereadtest.txt
fi

# If the file can't be deleted, the permission test fails.
if [ -f "$targetdir"/targetdirwritereadtest.txt ]
then
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : There was a probe file that could not be deleted, exiting." >> "$scriptdir/log_rec_copy.txt"
    echo "End of script. The target write-read permissions test failed, check the log."
    exit 0
fi

# After this line the email will be sent if the copying fails.

# Next create a the probe file.
touch "$targetdir"/targetdirwritereadtest.txt
sleep 10

# Check that the probe file was created, otherwise try remounting and re-touching.
if [ -f "$targetdir"/targetdirwritereadtest.txt ]
then
    # This is the expected case, and the file was created, no logging.
    echo "The probe file was created, continuing."
else
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : Could not write a file in the $targetdir folder, trying to remount." >> "$scriptdir/log_rec_copy.txt"
    sudo mount -a
    sleep 30
    touch "$targetdir"/targetdirwritereadtest.txt
    sleep 10
fi

# And now check that the file is there, otherwise.
if [ -f "$targetdir"/targetdirwritereadtest.txt ]
then
    # This is still the expected case.
    echo "Double-check passed, continuing."
else
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : The probe file could not be created." >> "$scriptdir/log_rec_copy.txt"
    echo "The target write-read permissions test failed, check the log."
fi

sleep 1
echo "2" >> "$targetdir"/targetdirwritereadtest.txt
targettestread=$(<"$targetdir/targetdirwritereadtest.txt")
rm "$targetdir"/targetdirwritereadtest.txt

if [ "$targettestread" != 2 ]
then
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : The write-read test for $targetdir failed. Check that 1) the folder is valid and 2) all users have write permissions." >> "$scriptdir/log_rec_copy.txt"
    /bin/cp "$filefull" "$rescuedir"
    echo "TVHeadend was unable to copy the recording $filebase to $targetdir. The file was copied to $rescuedir , please move the files manually before the space runs out. " | mail -s "TVHeadend file copy error" "$emailtarget"
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : The copying of the file $filebase failed and the file was copied to the rescuedir ( $rescuedir ). A mail was sent to $emailtarget . " >> "$scriptdir/log_rec_copy.txt"
    echo "End of script, the target directory was did not pass write-read test, check the log."
    exit 0
fi

# If the script has gotten this far, all the set parameters should be valid and the target folder has sufficient permissions for copying.
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : Target folder $targetdir seems to be mounted OK, copying the file $filebase ." >> "$scriptdir/log_rec_copy.txt"
    /bin/cp "$filefull" "$targetdir"

sleep 3

# Let's make sure that the copying was successful by comparing the file sizes.
sourcesize=$(stat -c%s "$filefull")
targetsize=$(stat -c%s "$targetdir/$filebase")

# The next line is commented out, it was useful for debugging but now gives ugly output.
# echo "Source size is $sourcesize and target size is $targetsize ."

# If the target file size matches the source, the process is logged as a success and we're ready.
if [ "$sourcesize" = "$targetsize" ]
then
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : The file $filebase was succesfully copied to $targetdir ." >> "$scriptdir/log_rec_copy.txt"
    echo "End of script. The source file was succesfully copied to the target directory."
# Otherwise the source file is copied to a rescue directory (rescuedir is "safe" from TVH, which deletes recordings after are x days (but the space might be limited)).
else
    /bin/cp "$filefull" "$rescuedir"
    echo "TVHeadend was unable to copy the recording $filebase to $targetdir. The file was copied to rescue directory, please move the files manually before the space runs out. " | mail -s "TVHeadend file copy error" "$emailtarget"
    curdatetime=$(date +"%d/%m/%Y %R")
    echo "$curdatetime : The copying of the file $filebase failed and the file was copied to the rescuedir ( $rescuedir ). A mail was sent to $emailtarget . " >> "$scriptdir/log_rec_copy.txt"
    echo "End of script. The target did not match the source and the file was copied to the rescue folder. Check the log."
fi

exit 0
