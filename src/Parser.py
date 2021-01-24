"""

Author : Cagri Karaman
Date : 20212401

Script to parse the measurements table from
 DSI Akim Gözlem Yıllıkları at https://www.dsi.gov.tr/Sayfa/Detay/744

file : PDF file to be parsed
page : Page of the table
year : year of the measuremtn (water year)
extract : Extraction of the data in csv format

Dependency : pandas , pdfplumber

"""

import os
import pdfplumber
import pandas as pd
import re
import datetime
import calendar
import random


def get_line_number(phrase, text):
    for i, t in enumerate(text):
        if phrase in t:
            return i


def extractpage(file, page, year_, extract=True):
    df_all = pd.DataFrame()
    match = ["Gün", "Maks"]  # Could be [GUN/AY] | for year < 2008

    with pdfplumber.open(file) as pdf:
        pages = pdf.pages
        text = pages[page].extract_text()

        if text != None and all(x in text for x in match):

            # if
            text = text.split('\n')
            cnt = get_line_number("YERİ", text)
            if cnt is None:
                cnt = get_line_number("YERĠ", text)
            name = text[cnt - 2]
            name = name.strip().replace(' ', '_')
            station = name.split('_')[0]

            try:
                dec = re.findall(r"\d+", text[get_line_number("Doğu", text)])
            except:
                assert len(dec) != 0

            if len(dec) == 0 or len(dec) < 5:
                dec = re.findall(r"\d+", text[cnt + 1])

            try:
                dec = [int(i) for i in dec]
                lon = dec[0] + dec[1] / 60 + dec[2] / 3600
                lat = dec[3] + dec[4] / 60 + dec[5] / 3600
            except:
                print(f"dec error at page {page + 1}")

            try:
                str_2 = text[get_line_number('YAĞIŞ ALANI', text)]
            except:
                str_2 = text[get_line_number('YAĞIġ ALANI', text)]
            t = re.findall("\d+\.?\d*", str_2)

            try:
                basin_area = t[0]
                elevation = t[-1]
            except:
                basin_area = None
                elevation = None

            # temp = {'Station': station, 'Name': name, 'lon': round(lon, 4), 'lat': round(lat, 4),
            #         'Basin_Area': basin_area,
            #         'Elevation': elevation}

            line_cnt = ["Gün", "Maks"]  # Could be ["GUN/AY", "Maks"] as well

            lines = [get_line_number(i, text) for i in line_cnt]
            table = text[lines[0] + 2:lines[1] - 1]
            table = list(filter(None, table))

            temp = []
            for i, line in enumerate(table):
                t = line.split(' ')
                t = list(filter(None, t))
                t = [i.replace('------', '') for i in t]
                t = [i.replace('-----', '') for i in t]
                t = [i.replace(',', '.') for i in t]
                t = [i.replace('KURU', '') for i in t]
                temp.append(t)

            temp = list(filter(None, temp))
            temp = list(map(list, zip(*temp)))
            temp = temp[1:]

            year = year_ - 1
            months = (10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8, 9)
            leap = {'10': 31, '11': 30, '12': 31, '1': 31, '2': 28, '3': 31, '4': 30, '5': 31, '6': 30, '7': 31,
                    '8': 31,
                    '9': 30}
            years = (
                year, year, year, year + 1, year + 1, year + 1, year + 1, year + 1, year + 1, year + 1, year + 1,
                year + 1)

            data = []
            for i in range(len(temp)):
                yy = years[i]
                mm = months[i]

                # Check leap year
                if calendar.isleap(year + 1):
                    leap['2'] = 29

                # check length of months
                for j in range(leap[str(mm)]):
                    data.append(
                        {'Date': datetime.date(yy, mm, 1) + datetime.timedelta(days=j), 'Dischage': temp[i][j]})

            df = pd.DataFrame(data)
            df['Name'] = name
            df['Station'] = station
            df['lon'] = round(lon, 4)
            df['lat'] = round(lat, 4)
            df['Basin_Area'] = basin_area
            df['Elevation'] = elevation
            df_all = df_all.append(df)

            if extract:
                df_all.to_csv(os.path.join(folder, f'{station}_{year_}.csv'), index=False)

            print(f"Station {station} extracted")
        else:
            print(f"No data could be found at page {page} to parse !!!")

    return df_all


if __name__ == '__main__':
    folder = '../data'
    file = 'dsi_2014.pdf'
    year = 2014
    extractpage(os.path.join(folder, file), page=558, year_=year, extract=True)

    # Test
    # pages = [random.randint(0, 1000) for i in range(10)]
    # for page in pages:
    #     extractpage(os.path.join(folder, file), page=page, year_=year, extract=True)
