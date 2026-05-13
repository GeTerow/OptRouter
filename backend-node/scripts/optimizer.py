import os
import sys
import json
import googlemaps
from datetime import datetime
from urllib.parse import quote_plus

if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

API_KEY = os.environ.get("GOOGLE_MAPS_API_KEY")

def format_time(seconds):
    h = seconds // 3600
    m = (seconds % 3600) // 60
    if h:
        return f"{h}h {m}min"
    elif m:
        return f"{m}min"
    else:
        return f"{seconds}s"

def optimize_route(addresses):
    if not API_KEY:
        print(json.dumps({"error": "A chave da API do Google Maps não está configurada."}), file=sys.stderr)
        sys.exit(1)

    if len(addresses) < 2:
        print(json.dumps({"error": "São necessários pelo menos dois endereços."}), file=sys.stderr)
        sys.exit(1)

    gmaps = googlemaps.Client(key=API_KEY)

    try:
        directions_result = gmaps.directions(
            origin=addresses[0],
            destination=addresses[0],
            waypoints=addresses[1:],
            optimize_waypoints=True,
            mode="driving",
            departure_time=datetime.now(),
            language="pt-BR"
        )
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(1)

    if not directions_result:
        print(json.dumps({"error": "Nenhum resultado retornado pela API do Google Maps."}), file=sys.stderr)
        sys.exit(1)

    route = directions_result[0]
    waypoint_order = route.get('waypoint_order', [])
    legs = route.get('legs', [])

    final_ordered_stops = [addresses[0]]
    for idx in waypoint_order:
        final_ordered_stops.append(addresses[idx + 1])
    final_ordered_stops.append(addresses[0])

    base_url = "https://www.google.com/maps/dir"
    encoded_addresses = [quote_plus(addr) for addr in final_ordered_stops]
    maps_url = f"{base_url}/{'/'.join(encoded_addresses)}"

    total_secs = sum(leg['duration']['value'] for leg in legs)
    total_m = sum(leg['distance']['value'] for leg in legs)

    output = {
        "totalTime": format_time(total_secs),
        "totalDistance": f"{(total_m / 1000):.1f} km",
        "numberOfStops": len(final_ordered_stops),
        "stops": [
            {"name": f"Parada {i+1}", "address": addr}
            for i, addr in enumerate(final_ordered_stops)
        ],
        "mapsUrl": maps_url
    }

    print(json.dumps(output, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    if len(sys.argv) > 1:
        input_addresses = sys.argv[1:]
        optimize_route(input_addresses)
    else:
        print(json.dumps({"error": "Nenhum endereço fornecido."}), file=sys.stderr)
        sys.exit(1)