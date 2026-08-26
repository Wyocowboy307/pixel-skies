class_name FlightModel
extends RefCounted

var id: String
var aircraft_id: String
var origin_airport_id: String
var destination_airport_id: String
var departure_unix: int
var arrival_unix: int
var payload_ids: Array[String] = []
var settled := false

func progress(now_unix: int) -> float:
    if arrival_unix <= departure_unix:
        return 1.0
    return clampf(float(now_unix - departure_unix) / float(arrival_unix - departure_unix), 0.0, 1.0)

func is_complete(now_unix: int) -> bool:
    return now_unix >= arrival_unix
