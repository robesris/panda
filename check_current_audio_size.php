<?php

$tempname = $_GET['tempname'];
$video_url = $_GET['video_url'];

$current_size = filesize('./' . $tempname . '.mp3');

print "currentSize=$current_size"; 
?>