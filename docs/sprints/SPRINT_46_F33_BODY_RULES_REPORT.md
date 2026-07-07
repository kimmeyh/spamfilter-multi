# Sprint 46 F33 -- Body Rules Cleanup Report

**Environment**: dev
**Mode**: DRY-RUN (no changes)
**Total body-condition rules**: 1109

## Group counts

| Group | Meaning | Action | Count |
|-------|---------|--------|-------|
| G1 | ALL domain-shaped w/ full `.tld` (Option B) | Convert to URL-anchored regex | 647 |
| G2 | keyword/phrase misclassified as domain | Reclassify metadata (body unchanged) | 84 |
| G4 | adamshetzner without `.tld` | Remove | 2 |
| G5 | orphan / empty condition_body | Remove | 0 |
| G6 | truncated/bare `/label\.` or `/label`, no full tld | Remove | 371 |
| DUP | same-domain-root duplicates | Remove all but first | 2 |
| ? | ambiguous (does not fit) | Report only, untouched | 3 |

**Net removals**: 375. **Reclassified**: 84. **Converted**: 647.

## G1 conversions (sample)

- id=2154: `["/50\\.193\\.138\\.95"]` -> `["(?:://|[/.])50\.193\.138\.95"]`
- id=2155: `["/abbentek\\.com"]` -> `["(?:://|[/.])abbentek\.com"]`
- id=2156: `["/accountryside\\.com"]` -> `["(?:://|[/.])accountryside\.com"]`
- id=2158: `["/actiontee\\.com"]` -> `["(?:://|[/.])actiontee\.com"]`
- id=2160: `["/adianeos\\.com"]` -> `["(?:://|[/.])adianeos\.com"]`
- id=2161: `["/advancedsonography\\.com"]` -> `["(?:://|[/.])advancedsonography\.com"]`
- id=2163: `["/agagcp\\.com"]` -> `["(?:://|[/.])agagcp\.com"]`
- id=2164: `["/agedlikewine\\.com"]` -> `["(?:://|[/.])agedlikewine\.com"]`
- id=2165: `["/ahanim\\.com"]` -> `["(?:://|[/.])ahanim\.com"]`
- id=2166: `["/aimreturn\\.net"]` -> `["(?:://|[/.])aimreturn\.net"]`
- id=2167: `["/alilua\\.com"]` -> `["(?:://|[/.])alilua\.com"]`
- id=2168: `["/alpinegj\\.com"]` -> `["(?:://|[/.])alpinegj\.com"]`
- id=2169: `["/alsaqqr\\.com"]` -> `["(?:://|[/.])alsaqqr\.com"]`
- id=2170: `["/alsokar\\.com"]` -> `["(?:://|[/.])alsokar\.com"]`
- id=2171: `["/altaylarotomotiv\\.com"]` -> `["(?:://|[/.])altaylarotomotiv\.com"]`
- ... and 632 more

## G2 keyword reclassifications (84)

- `body_1501__yamato__roadcom` body=`["1501\\ yamato\\ road"]` subType=`entire_domain` src=`1501\ yamato\ roadcom`
- `body_32__98509__4054com` body=`["32\\ 98509\\ 4054"]` subType=`entire_domain` src=`32\ 98509\ 4054com`
- `body_a__date__withcom` body=`["a\\ date\\ with"]` subType=`entire_domain` src=`a\ date\ withcom`
- `body_a__local__girlcom` body=`["a\\ local\\ girl"]` subType=`entire_domain` src=`a\ local\ girlcom`
- `body_affordable__term__lifecom` body=`["affordable\\ term\\ life"]` subType=`entire_domain` src=`affordable\ term\ lifecom`
- `body_audacious___llccom` body=`["audacious,\\ llc"]` subType=`entire_domain` src=`audacious,\ llccom`
- `body_be__my__companioncom` body=`["be\\ my\\ companion"]` subType=`entire_domain` src=`be\ my\ companioncom`
- `body_build__a__romancecom` body=`["build\\ a\\ romance"]` subType=`entire_domain` src=`build\ a\ romancecom`
- `body_camp__lejeunecom` body=`["camp\\ lejeune"]` subType=`entire_domain` src=`camp\ lejeunecom`
- `body_cancer__lawsuitcom` body=`["cancer\\ lawsuit"]` subType=`entire_domain` src=`cancer\ lawsuitcom`
- `body_capital__funding___llccom` body=`["capital\\ funding,\\ llc"]` subType=`entire_domain` src=`capital\ funding,\ llccom`
- `body_clements__jamandrecom` body=`["clements\\ jamandre"]` subType=`entire_domain` src=`clements\ jamandrecom`
- `body_coinbase__globalcom` body=`["coinbase\\ global"]` subType=`entire_domain` src=`coinbase\ globalcom`
- `body_cwcramer__investmentscom` body=`["cwcramer\\ investments"]` subType=`entire_domain` src=`cwcramer\ investmentscom`
- `body_dates__with__mecom` body=`["dates\\ with\\ me"]` subType=`entire_domain` src=`dates\ with\ mecom`
- ... and 69 more

## G4 adamshetzner removals (2)

- `body_adamshetzner.com` body=`["/adamshetzner\\."]` subType=`entire_domain` src=`adamshetzner.com`
- `body_.adamshetzner.com` body=`["\\.adamshetzner\\."]` subType=`entire_domain` src=`.adamshetzner.com`

## G5 orphan removals (0)

_None._

## G6 truncated/bare removals (371)

- `body_acslogeg.com` body=`["/acslogeg\\."]` subType=`entire_domain` src=`acslogeg.com`
- `body_adventurousamend.com` body=`["/adventurousamend\\."]` subType=`entire_domain` src=`adventurousamend.com`
- `body_auenwindcom` body=`["/auenwind"]` subType=`entire_domain` src=`auenwindcom`
- `body_babyaliceacom` body=`["/babyalicea"]` subType=`entire_domain` src=`babyaliceacom`
- `body_babysharkystorecom` body=`["/babysharkystore"]` subType=`entire_domain` src=`babysharkystorecom`
- `body_bangalaroodcom` body=`["/bangalarood"]` subType=`entire_domain` src=`bangalaroodcom`
- `body_beliastick.com` body=`["/beliastick\\."]` subType=`entire_domain` src=`beliastick.com`
- `body_bogmilcom` body=`["/bogmil"]` subType=`entire_domain` src=`bogmilcom`
- `body_budyingsendersrorecom` body=`["/budyingsendersrore"]` subType=`entire_domain` src=`budyingsendersrorecom`
- `body_buyplaydiscover.com` body=`["/buyplaydiscover\\."]` subType=`entire_domain` src=`buyplaydiscover.com`
- `body_campgumuscom` body=`["/campgumus"]` subType=`entire_domain` src=`campgumuscom`
- `body_chitanodailycom` body=`["/chitanodaily"]` subType=`entire_domain` src=`chitanodailycom`
- `body_differenchiopia.com` body=`["/differenchiopia\\."]` subType=`entire_domain` src=`differenchiopia.com`
- `body_dlefm.com` body=`["/dlefm\\."]` subType=`entire_domain` src=`dlefm.com`
- `body_easiereatscom` body=`["/easiereats"]` subType=`entire_domain` src=`easiereatscom`
- ... and 356 more

## DUP duplicate removals (2)

- `body_cahamsonsmakj.art_2` body=`["cahamsonsmakj\\.art/"]` subType=`entire_domain` src=`cahamsonsmakj.art`
- `body_mcdatoto.com_2` body=`["mcdatoto\\.com"]` subType=`entire_domain` src=`mcdatoto.com`

## Ambiguous (untouched -- review) (3)

- `body_800-571-7438com` body=`["800\\-571\\-7438"]` subType=`entire_domain` src=`800-571-7438com`
- `body_.nl` body=`["\\.nl/"]` subType=`entire_domain` src=`.nl`
- `body_sys-confg.co.ukcl` body=`["sys\\-confg\\.co\\.uk/cl/"]` subType=`entire_domain` src=`sys-confg.co.ukcl`

