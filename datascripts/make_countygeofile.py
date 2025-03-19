#!/bin/env python3

import os

import settings


class CountyShapefileConverter:
    def run(self):
        print("CountyShapefileConverter")

        print("    Reading {}".format(settings.INPUT_COUNTYBOUNDS_SHP))

        command = "{} {} -quiet -rename-layers {} -filter-fields {} -rename-fields {} -simplify dp {} -o format=topojson quantization={} precision={} {}".format(
            settings.MAPSHAPER_CLI,
            settings.INPUT_COUNTYBOUNDS_SHP,
            'counties',
            ','.join([
                settings.COUNTYBOUNDS_NAMEFIELD,
                settings.COUNTYBOUNDS_NUMBER
            ]),
            ','.join([
                "{}={}".format('Name', settings.COUNTYBOUNDS_NAMEFIELD),
                "{}={}".format('GEOID', settings.COUNTYBOUNDS_NUMBER)
            ]),
            settings.SIMPLIFY, settings.QUANTIZE, settings.LATLNGPRECISION,
            settings.OUTPUT_COUNTYJSON
        )
        os.system(command)

        print("    Wrote {}".format(settings.OUTPUT_COUNTYJSON))


if __name__ == '__main__':
    CountyShapefileConverter().run()
    print("DONE")
