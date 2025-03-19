import fiona
from shapely.geometry import shape
import os
import csv
import settings

class PlacesIntersector:
    def run(self):
        print("PlacesIntersector")

        self.reproject(settings.INPUT_ZONESFILE, settings.REPROJECTED_ZONESFILE, settings.CTAZONES_SHAPEFILE_IDFIELD, settings.CTAZONES_SHAPEFILE_NAMEFIELD)
        self.reproject(settings.INPUT_CITYBOUNDS_SHP, settings.REPROJECTED_CITY_SHP, settings.CITYBOUNDS_IDFIELD, settings.CITYBOUNDS_NAMEFIELD)
        self.reproject(settings.INPUT_COUNTYBOUNDS_SHP, settings.REPROJECTED_COUNTY_SHP, settings.COUNTYBOUNDS_IDFIELD, settings.COUNTYBOUNDS_NAMEFIELD, settings.COUNTYBOUNDS_NUMBER)

        self.findplaces(settings.REPROJECTED_CITY_SHP, settings.OUTPUT_CITYCSV, 'City')
        self.findplaces(settings.REPROJECTED_COUNTY_SHP, settings.OUTPUT_COUNTYCSV, 'County', county_code_field=settings.COUNTYBOUNDS_NUMBER)

    def reproject(self, inputshp, outputshp, idfield, namefield, countynumfield=None):
        # Reproject the shapefile to an Albers so we can do area calculations in findplaces()
        # and to standardize on there being only one attribute: name
        print("    Reproject {}  => {}".format(inputshp, outputshp))

        if countynumfield:
            command = "{} {} -proj {} -filter-fields {},{},{} -rename-fields name={},id={},countynum={} -o {} -quiet".format(
                'mapshaper',
                inputshp,
                settings.PLANAR_SRS,
                idfield, namefield, countynumfield,
                namefield, idfield, countynumfield,
                outputshp
            )
        else:
            command = "{} {} -proj {} -filter-fields {},{} -rename-fields name={},id={} -o {} -quiet".format(
                'mapshaper',
                inputshp,
                settings.PLANAR_SRS,
                idfield, namefield,
                namefield, idfield,
                outputshp
            )
        os.system(command)

    def findplaces(self, placesdataset, csvfilename, placecolumnname, county_code_field=None):
        print("    Calculating {}  =>  {}".format(placesdataset, csvfilename))

        with open(csvfilename, 'w', newline='') as outfh:
            csvfh = csv.writer(outfh)
            if county_code_field:
                csvfh.writerow(['ZoneIDOrig', placecolumnname, 'CountyCode'])
            else:
                csvfh.writerow(['ZoneIDOrig', placecolumnname])

            with fiona.open(settings.REPROJECTED_ZONESFILE, 'r') as ctads:
                for cta in ctads:
                    ctaid = cta['properties']['id']
                    ctageom = shape(cta['geometry'])

                    places = []

                    with fiona.open(placesdataset, 'r') as ds:
                        for place in ds:
                            place_geom = shape(place['geometry'])
                            intersection = place_geom.intersection(ctageom)

                            # Calculate intersection area in acres
                            iacres = intersection.area * settings.SQMETERS_TO_ACRES

                            if iacres >= 2000:
                                # name = place['properties']['name']
                                name = place['properties']['name']
                                if county_code_field:
                                    # county_code = place['properties'].get("StCoFIPS")
                                    county_code = place['properties']['countynum']
                                    # places.append((name, county_code))
                                    places.append((name, county_code))

                                else:
                                    places.append((name,))

                    # Unique-ify the list and write CSV rows
                    seen_places = set()
                    for place in places:
                        if place[0] not in seen_places:
                            seen_places.add(place[0])
                            if county_code_field:
                                csvfh.writerow([ctaid, place[0], place[1]])
                            else:
                                csvfh.writerow([ctaid, place[0]])

if __name__ == '__main__':
    PlacesIntersector().run()
    print("DONE")
