<?php
print "mp3ready=false";

$tempname = $_GET['tempname'];
$video_url = $_GET['video_url'];

system('touch ./' . $tempname . '.txt');
system('/var/www/staging/current/youtube-dl --output=/var/www/staging/current/public/game_demo/' . $tempname . '.flv --format=18 "' . $video_url . '" >> ' . $tempname . '.txt', $returnval);

print system('./ffmpeg -i /var/www/staging/current/public/game_demo/' . $tempname . '.flv -acodec libmp3lame -ac 2 -ab 128k -vn -y "/var/www/staging/current/public/game_demo/' . $tempname . '.mp3"', $returnval);

print "mp3ready=true"; 
?>
