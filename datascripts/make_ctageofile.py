#!/bin/env python3

import os

import settings


class ZoneFileConverter:
    def run(self):
        print("ZoneFileConverter")

        print("    Reading {}".format(settings.INPUT_ZONESFILE))

        command = "{} {} -quiet -rename-layers {} -filter-fields {} -rename-fields {} -simplify dp {} -o format=topojson quantization={} precision={} {}".format(
            settings.MAPSHAPER_CLI,
            settings.INPUT_ZONESFILE,
            'ctazones',
            ','.join([
                settings.CTAZONES_SHAPEFILE_IDFIELD,
                settings.CTAZONES_SHAPEFILE_NAMEFIELD
            ]),
            ','.join([
                "{}={}".format('ZoneIDOrig', settings.CTAZONES_SHAPEFILE_IDFIELD),
                "{}={}".format('ZoneName', settings.CTAZONES_SHAPEFILE_NAMEFIELD)
            ]),
            settings.SIMPLIFY, settings.QUANTIZE, settings.LATLNGPRECISION,
            settings.OUTPUT_CTATOPOJSON
        )
        os.system(command)

        print("    Wrote {}".format(settings.OUTPUT_CTATOPOJSON))


if __name__ == '__main__':
    ZoneFileConverter().run()
    print("DONE")
