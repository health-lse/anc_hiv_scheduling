"""
    this file contain auxiliary functions to clean
    or generate data that were already run, so the
    final datasets should already contain the result
    of this functions. This is more of a backup file
"""
import time
import openrouteservice

def get_driving_distance(lat_1, lon_1, lat_2, lon_2):
    """
    Example:
        lat_1=-25.9148
        lon_1=32.60992
        lat_2=-23.879878
        lon_2=35.389587

        get_driving_distance(lon_1, lat_1,
                             lon_2, lat_2)
    """
    opkey = "5b3ce3597851110001cf6248fb0ae865fbf74a4f8dae26493e8a9bb5"
    client = openrouteservice.Client(key=opkey)
    coords = ((lat_1, lon_1),
              (lat_2, lon_2))
    res = client.directions(coords)
    return res["routes"][0]["summary"]["distance"]

def query_driving_distances(facility_characteristics):
    capital_coords = {"Maputo Cidade":(-25.95973700292535, 32.582610231921656),
                        "Maputo Província":(-25.95973700292535, 32.582610231921656),
                        "Gaza":(-25.065748,33.678836),
                        "Inhambane":(-23.879878,35.389587)}

    driving_distance = {"facility_cod":[],"distance":[]}
    for i, row in facility_characteristics.iterrows():
        time.sleep(1)
        lon_province = capital_coords[row["province"]][1]
        lat_province = capital_coords[row["province"]][0]

        lon_facility = row["q014_b"]#row["q013_b"]
        lat_facility = row["q013_b"]#row["q014_b"]

        distance = 0
        try:
            distance = get_driving_distance(lon_province, lat_province,
                                            lon_facility, lat_facility)
        except:
            print(f"route not found for facility")

        driving_distance["facility_cod"].append(row["facility_cod"])
        driving_distance["distance"].append(distance)

    driving_distance["facility_cod"].append(64)
    driving_distance["distance"].append(33000)
    distance_df = pd.DataFrame(driving_distance)
    return distance_df

def gen_distance_to_province_df():
    """
        creates dta containing the distance from
        each facility to the capital of the province
    """
    facility_characteristics = pd.read_stata(f"{AUX}/facility_characteristics.dta")
    distance_df = query_driving_distances(facility_characteristics)
    distance_df.to_stata(f"{AUX}/distance_to_district_capital.dta")