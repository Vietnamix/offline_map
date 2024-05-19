<?php

    /**
		by Eric Guiffault
		2022-03-14
	**/

	// Grab the picture details
	$x = $_GET["x"];
	$y = $_GET["y"];
	$z = $_GET["z"];
	
	// Check first if this file exists, if yes display it, if not check the folder and download the picture
	$zfile = './OSM/' . $x . '/' . $y . '/' . $z . '.png';
	//$zfile = './OSM/test4.png';
	if (file_exists($zfile)) {
		//echo 'File exists: ' . $zfile . '<br>' ;
	 } else {	
		//echo 'File does not exists: ' . $zfile . '<br>' ;
		cfolder('./OSM/' . $x );
		cfolder('./OSM/' . $x . '/' .  $y );
		//echo 'https://tile.openstreetmap.org/' . $x . '/' . $y . '/' . $z . '.png' ;
		//$letters = array_merge(range('a','z'));
		//getimg('https://' . $letters[rand(0,3)] . '.tile.openstreetmap.org/' . $x . '/' . $y . '/' . $z . '.png',$x,$y,$z);
		getimg('https://tile.openstreetmap.org/' . $x . '/' . $y . '/' . $z . '.png',$x,$y,$z);
		//echo '<img src="'.getimg('https://tile.openstreetmap.org/' . $x . '/' . $y . '/' . $z . '.png',$x,$y,$z).'">';
			
	}
	
	//echo '<img src="https://leroy.fr/wp-content/plugins/_Ricus/OSM/' . $x . '/' . $y . '/' . $z . '.png"';	  
	//echo '<br>';
	
	//$im = 'https://leroy.fr/wp-content/plugins/_Ricus/OSM/' . $x . '/' . $y . '/' . $z . '.png'
	$im = imagecreatefrompng($zfile);
	header('Content-Type: image/png');	
	imagepng($im);
	
	// Go catch the picture using a user agent
	function getimg($url,$x,$y,$z) {
		
		$options = array(
		  'http'=>array(
			'method'=>"GET",
			'header'=>"User-Agent: Mozilla/5.0 (Android; Mobile; rv:40.0) Gecko/40.0 Firefox/40.1"
		  )
		);

		$context = stream_context_create($options);
		$image = file_get_contents($url, false, $context);

		//Obtem o Mime Type
		$file_info = new finfo(FILEINFO_MIME_TYPE);
		$mime_type = $file_info->buffer($image);

		// Save the picture
		$data = 'data:'.$mime_type.';base64,'.base64_encode($image);
		$data = base64_decode(preg_replace('#^data:image/\w+;base64,#i', '', $data));
		file_put_contents('./OSM/' . $x . '/' . $y . '/' . $z . '.png', $data);
		
		// Display the picture
		return 'data:'.$mime_type.';base64,'.base64_encode($image);	
		
	} 

	// Check if the folder exists, if not create it
	function cfolder($zfolder) {
		
		if (is_dir($zfolder)){  
			//echo 'Folder exists: ' . $zfolder . '<br>' ;
		 } else {	
			//echo 'Folder does not exists: ' . $zfolder . '<br>' ;
			mkdir($zfolder, 0777, true);
			chmod($zfolder, 0777);
		}	
	}
	


?>