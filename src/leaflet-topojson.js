L.TopoJSON = L.GeoJSON.extend({
    addData: function (data) {
        var geojson, key;
        if (data.type === "Topology") {
            for (key in data.objects) {
                if (data.objects.hasOwnProperty(key)) {
                    geojson = topojson.feature(data, data.objects[key]);
                    L.GeoJSON.prototype.addData.call(this, geojson);
                }
            }
            return this;
        }
        L.GeoJSON.prototype.addData.call(this, data);
      return this;
    }
});

L.topoJson = function (data, options) {
    return new L.TopoJSON(data, options);
};
