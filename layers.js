var wms_layers = [];


        var lyr_OpenStreetMap_0 = new ol.layer.Tile({
            'title': 'OpenStreetMap',
            'type': 'base',
            'opacity': 1.000000,
            
            
            source: new ol.source.XYZ({
    attributions: ' ',
                //url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
				//url: 'https://leroy.fr/wp-content/plugins/_Ricus/pics.php?x={z}&y={x}&z={y}'
				url: 'http://localhost:8086/{z}/{x}/{y}'
            })
        });

lyr_OpenStreetMap_0.setVisible(true);
var layersList = [lyr_OpenStreetMap_0];
