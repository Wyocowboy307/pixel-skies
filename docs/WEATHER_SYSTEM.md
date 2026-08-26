# Weather System

## Role

Weather should make the world feel alive and occasionally change a route decision without turning Pixel Skies into a meteorology simulator.

## Weather types

Vertical slice visuals can support:
- clear
- cloud
- rain
- snow
- fog
- thunderstorm
- strong wind

Only a subset needs mechanical effects initially.

## World presentation

Weather exists as moving regional cells/overlays on the flat map.

At far zoom:
- simplified cloud/storm blobs
- route warning colors/icons

At regional zoom:
- visible cloud motion
- rain/snow texture
- storm boundary

At airport:
- runway wet/snow variation
- windsock
- precipitation
- ramp lighting/fog

## Mechanical effect budget

Start simple:
- weather may add turnaround/delay time;
- severe weather may temporarily discourage a route;
- snow can require an airport equipment upgrade later;
- wind can affect small aircraft more than large aircraft.

Do not simulate winds aloft, METAR parsing or live real-world weather in the vertical slice.

## Forecast UX

Route planner may show:
- green: normal
- yellow: delay risk
- red: severe / unavailable

One sentence explains why.

## Generation

Weather should be deterministic from a seeded timeline for tests. Offline progress advances cells from timestamps.
