# Rackmount Redundant 12V Power Supply

This is a redundant, but not hot-swappable, 12VDC power supply.  It has these features:

 - Two AC cords.  Either cord can lose AC power without disrupting the 12VDC output.

 - Five 12VDC output jacks.  Any individual jack can supply ~6A maximum but the supply is only capable of providing ~16A maximum across all jacks.

 - Remote monitoring.  A serial port provides a simple "on/off" status that indicates when one of the two onboard DC supplies loses its AC power or otherwise fails.

It is built on a 1U rack shelf but requires at least 2U because it is slightly taller than 1U.  The extra air space is also needed for cooling as the supply has no fans.

## Background

Rackmount [Automatic Transfer Switches](https://web.archive.org/web/20220408134749/https://www.youtube.com/watch?v=JSWmmY9tKrM) from companies such as [APC](https://web.archive.org/web/20220408135631/https://download.schneider-electric.com/files?p_File_Name=BSTY-AQNP38_R0_EN.pdf&p_Doc_Ref=SPD_BSTY-AQNP38_EN&p_enDocType=Catalog) and [CyberPower](https://web.archive.org/web/20220408140138/https://www.cyberpower.com/tw/en/File/GetCyberpowerFileByDocId/DS-21040002-01) can be used to provide AC power redundancy for devices with a single AC cord such as unmanaged switches and small firewall appliances.  These devices are usually powered by small power bricks.  All of the bricks are plugged into the ATS which in turn has two AC cords.

I noticed that all of the small power bricks in my rack had 12VDC output.  Instead of buying an ATS unit and plugging the bricks into it, I decided to eliminate the bricks by building this redundant 12VDC supply.  It can be built for less than the cost of most ATS units and eliminates the clutter of the bricks.

## Parts List

| Part | Qty | Notes |
|------|-----|-------|
|[Meanwell ERDN40-12 12VDC Redundancy Module](https://www.mouser.com/ProductDetail/709-ERDN40-12) | 1 | [Datasheet](https://web.archive.org/web/20220407021145/https://www.meanwell.com/upload/pdf/ERDN40/ERDN40-spec.pdf) |
|[Meanwell MSP-200-12 12VDC 16.7A Power Supply](https://www.mouser.com/ProductDetail/709-MSP200-12) | 2 | [Datasheet](https://web.archive.org/web/20220407021309/https://www.mouser.com/datasheet/2/260/MSP_200_SPEC-1109886.pdf).  Selected for built-in protections and no required minimum current. |
|[Pinfox 10' 18 AWG 3 Prong Heavy Duty 120V 10A AC Cord](https://www.amazon.com/gp/product/B07QYRMD6D) | 2 | One AC cord for each MSP-200-12. |
|[Raising Electronics 701401004 19" 1U 12" Deep Rack Shelf](https://www.amazon.com/gp/product/B01M8HKRA7) | 1 | [Product Page](https://web.archive.org/web/20220408132026/https://risingracks.com/cantilever-server-shelf-vented-black-shelves-rack-mount-19-1u-12-300mm-deep/) |
|[M3x6mm Plastic Pan Head Screw](https://www.ebay.com/itm/254913074827) | 10 | For mounting Meanwell units to shelf.  Plastic screws were selected to ensure no possibility of shorting. |
|[Hammond 1591HSBK Project Box](https://www.mouser.com/ProductDetail/546-1591HS-BK) | 1 | [Datasheet](https://web.archive.org/web/20220407164638/https://www.mouser.com/datasheet/2/177/1591-1389824.pdf) |
|[Switchcraft L712ASH 2.5mm Locking Barrel Socket](https://www.mouser.com/ProductDetail/502-L712ASH) | 5 | [Datasheet](https://web.archive.org/web/20220407035419/https://www.mouser.com/datasheet/2/393/L712ASH-L722ASH_CD-1110860.pdf), [Bulletin](https://web.archive.org/web/20220407164041/https://www.switchcraft.com/Documents/switchcraft_npb_637_high_temp_jacks_plugs.pdf).  Mounted on project box for DC outputs. |
|[Switchcraft 761KSH15 2.5mm Locking Barrel Plug](https://www.mouser.com/ProductDetail/502-761KSH15) | 5 | [Datasheet](https://web.archive.org/web/20220407035117/https://www.mouser.com/datasheet/2/393/761KSH-S761KSH_CD-1110850.pdf). See bulletin above for electrical info.  For building DC cables out to devices. |
|[14 AWG GXL Wire 10' Long](https://www.ebay.com/itm/293094627307) | 3 | 1 each: red, green, black.  Cut to length for high current DC wiring |
|[DC Extension Cable 18 AWG 12VDC 10A 33' Long](https://www.ebay.com/itm/133233779533) | 1 | Connectors cut off and discarded; used to make output cables and for wiring inside Project Box |
|[10pc Dupont 2x2 Female Housing](https://www.ebay.com/itm/141510327734) | 1 | 1 housing used to make ERDN40 alarm cable |
|[10pc Dupont 2-pin 26AWG Female-Female Jumper Cable](https://www.ebay.com/itm/254959908608) | 1 | 2 cables used to make ERDN40 alarm cable |
|[125pc Rubber Grommet Set](https://www.ebay.com/itm/221291687081) | 1 | 1 grommet used around wiring from ERDN40 into project box |
|[TICONN 80pc Stainless Steel Hose Clamp Set](https://www.amazon.com/gp/product/B094YP2F3D) | 1 | 3 hose clamps used for AC cord strain relief |
|[100pc 1/4" Aluminum Pop Rivet Set](https://www.harborfreight.com/100-piece-1-4-quarter-inch-aluminum-blind-rivet-set-67619.html) | 1 | 3 pop rivets used to secure hose clamps to shelf |
|[6pc Phoneix Contact Cable Tie Mount Base](https://www.mouser.com/ProductDetail/651-3240709) | 1 | 3 bases used for cable management |
|[Panduit Cable Tie Assortment](https://www.mouser.com/ProductDetail/644-KB-550) | 1 | 3 ties used for cable management |
|[42pc Marine Heat Shrink Tubing](https://www.harborfreight.com/42-piece-marine-heat-shrink-tubing-67598.html) | 1 | For insulating cable ends and also cable management |

## Author

[Mike Naberezny](https://github.com/mnaberez)
