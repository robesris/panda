<?php
print "mp3ready=false";

$tempname = $_GET['tempname'];
$video_url = $_GET['video_url'];


// for local
system('/usr/local/bin/youtube-dl --output=./' . $tempname . '.flv --format=18 "' . $video_url . '"', $returnval);
print system('/opt/local/bin/ffmpeg -i /Applications/MAMP/htdocs/game_demo/' . $tempname . '.flv -acodec libmp3lame -ac 2 -ab 128k -vn -y "/Applications/MAMP/htdocs/game_demo/' . $tempname . '.mp3"', $returnval);

print "mp3ready=true"; 
?>
