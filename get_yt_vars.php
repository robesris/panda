<?php
  $tempname = $_GET['tempname'];
  $video_url = $_GET['video_url'];

  $video_id_string_begin_pos = strpos($video_url, "v=") + 2;
  $video_id_string_end_pos = strpos($video_url, '&', $video_id_string_begin_pos);
  if (!$video_id_string_end_pos) { 
    $video_id_string_end_pos = strlen($video_url); 
  }
  $video_id = substr($video_url, $video_id_string_begin_pos, $video_id_string_end_pos - $video_id_string_begin_pos);
  $video_xml_url = 'https://gdata.youtube.com/feeds/api/videos/' . $video_id . '?v=2';
  system('wget --no-check-certificate -O ./' . $tempname . '.xml ' . $video_xml_url);
  $xml_str = file_get_contents('./' . $tempname . '.xml');
  $xml = new SimpleXMLElement($xml_str);
  $namespaces = $xml->getNameSpaces(true);

  $video_title = ereg_replace("[^-A-Za-z0-9 ]", "", $xml->title);
  $video_duration = $xml->xpath("//yt:duration");
  $video_duration = $video_duration[0]['seconds'];

  print "video_title=" . $video_title . "&video_duration=" . $video_duration . "&video_id=" . $video_id;
?>
