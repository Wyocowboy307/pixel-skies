# Pixel Skies — Art Bible

## Identity

A clean, charming 2D pixel aviation world.

Not photorealistic, not vector-flat corporate UI, not a muddy retro filter, and not toy-chibi planes with impossible proportions.

The aircraft should be recognizable by silhouette while remaining original fictional designs.

## Perspective

### World / airport
Top-down flat-lay with only a tiny amount of readable roof/side information where needed. The plane must read primarily from above.

### Aircraft detail
Pure side profile / slight presentation profile. No dramatic perspective.

## Pixel language

- crisp nearest-neighbor presentation
- controlled palette per environment
- consistent pixel density
- 1–2 px colored outlines at asset native scale
- upper-left light direction
- restrained highlights
- shadows simple and readable

## Scale tiers

### Top-view aircraft canvas targets
- small: 48×48 or 64×64
- medium: 96×96
- large: 128×128
- heavy/special: up to 160×160

Transparent background.

### Side-profile targets
- small: ~160×64
- medium: ~256×96
- large: ~384×128

Transparent background and consistent baseline.

### Airport
Base tile language: 16×16 or 32×32 modules. Large buildings may occupy many tiles.

## Aircraft readability

At map scale:
- nose direction obvious
- wing shape obvious
- prop vs jet obvious
- airline color visible
- avoid tiny rivet/detail noise

At airport scale:
- windows/doors
- engine/prop animation
- gear
- nav lights
- livery stripe/tail mark

## Airport readability

Runway must instantly differ from taxiway/apron.

Use strong runway edge/center markings, taxiway tone shift, parking stand markings, terminal/hangar roof silhouettes and tiny service vehicles for scale.

## Biomes

Airports inherit subtle regional flavor: mountain, plains, desert, coastal, snowy, tropical and urban.

Do not make every airport a bespoke tileset. Use modular regional decoration packs.

## Weather

Weather should be readable from far zoom: cloud groups, rain front, snow, thunderstorm cells and fog haze. Do not obscure route/airport information.

## Animation targets

Aircraft:
- prop spin / engine start
- nav beacon blink
- taxi roll
- takeoff acceleration
- rotation/liftoff presentation
- landing touchdown puff
- braking/reverse indication
- door/cargo hatch
- small ground-service motion

World:
- clouds drift
- route highlight pulses
- plane markers move continuously

Airport:
- vehicles approach/leave
- ramp lights
- windsock
- passengers/cargo represented simply

## AI art rejection rules

Reject if:
- aircraft changes proportions between top and side view;
- wings/engines are asymmetric without reason;
- transparent edges are anti-aliased/blurry;
- pixel density varies inside one asset;
- baked background/shadow cannot be removed;
- runway markings are unreadable;
- generator invents text/logos;
- silhouette is too close to a recognizable exact aircraft design when using fictional families.

Consistency beats detail.
