<?php

    /**
     * Tile Cache for Offline Map Construction
     * 
     * This script caches tiles for constructing an offline map. 
     * It fetches tiles from the OpenStreetMap service and stores them locally.
     * 
     * @package OfflineMapCache
     * @author Eric Guiffault
     * @version 1.0
     * @since 2022-03-14
     **/

    // Retrieve tile coordinates from the query parameters
    $x = $_GET["x"];
    $y = $_GET["y"];
    $z = $_GET["z"];
    
    // Construct the local file path for the tile
    $zfile = './OSM/' . $x . '/' . $y . '/' . $z . '.png';

    // Check if the tile already exists locally
    if (!file_exists($zfile)) {
        // If the tile does not exist, ensure the necessary directories exist
        cfolder('./OSM/' . $x);
        cfolder('./OSM/' . $x . '/' . $y);
        
        // Fetch and save the tile from OpenStreetMap
        getimg('https://tile.openstreetmap.org/' . $x . '/' . $y . '/' . $z . '.png', $x, $y, $z);
    }

    // Load the tile image
    $im = imagecreatefrompng($zfile);
    
    // Set the content type header to display the image
    header('Content-Type: image/png');	
    imagepng($im);
    
    /**
     * Fetches an image from the specified URL and saves it locally.
     *
     * @param string $url The URL of the image to fetch.
     * @param int $x The x-coordinate of the tile.
     * @param int $y The y-coordinate of the tile.
     * @param int $z The zoom level of the tile.
     * @return string The base64-encoded image data.
     */
    function getimg($url, $x, $y, $z) {
        $options = array(
            'http' => array(
                'method' => "GET",
                'header' => "User-Agent: Mozilla/5.0 (Android; Mobile; rv:40.0) Gecko/40.0 Firefox/40.1"
            )
        );

        $context = stream_context_create($options);
        $image = file_get_contents($url, false, $context);

        // Get the MIME type of the image
        $file_info = new finfo(FILEINFO_MIME_TYPE);
        $mime_type = $file_info->buffer($image);

        // Save the image locally
        $data = 'data:' . $mime_type . ';base64,' . base64_encode($image);
        $data = base64_decode(preg_replace('#^data:image/\w+;base64,#i', '', $data));
        file_put_contents('./OSM/' . $x . '/' . $y . '/' . $z . '.png', $data);
        
        // Return the base64-encoded image data
        return 'data:' . $mime_type . ';base64,' . base64_encode($image);	
    }

    /**
     * Checks if a folder exists and creates it if it does not.
     *
     * @param string $zfolder The path of the folder to check/create.
     */
    function cfolder($zfolder) {
        if (!is_dir($zfolder)) {  
            mkdir($zfolder, 0777, true);
            chmod($zfolder, 0777);
        }	
    }

?>
