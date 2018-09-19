# rec_copy.sh
A linux bash shell script to copy recordings (as a post processor command)

This script is supposed to be executed after each recording,
from TVHeadend, as the post-processor command.

The script expects one parameter: the only parameter ($1) should point
to the source file with the full path (i.e. /home/pi/rec/foobar.mkv).
This can be easily passed from TVHeadend's internal variable system.
(e.g. TVHeadend post-proc syntax: /home/pi/utilities/rec_copy.sh "%f")

There are prerequisites. Please check that the target folder has
write premissions for all users. Also, please check the permissions for
all users in the script directory (for logging) and the rescue directory
(in case the copying to target directory fails). Also, ssmtp and mailutils
need to be installed for the mail notification to work, please test that
emailing works beforehand. Email is only sent if the process fails because
of target folder problems os copying mismatch, other variables should be
tested in advance.
