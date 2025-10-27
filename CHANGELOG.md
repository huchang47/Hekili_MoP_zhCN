# Hekili

## [v5.5.1-1.0.0m](https://github.com/Smufrik/Hekili/tree/v5.5.1-1.0.0m) (2025-10-26)
[Full Changelog](https://github.com/Smufrik/Hekili/compare/v5.5.1-1.0.0l...v5.5.1-1.0.0m) [Previous Releases](https://github.com/Smufrik/Hekili/releases)

- MoP DK: Frost/Blood ERW gating and death-rune counting; Blood APL fixes  
- feat: Enhance Enhancement Shaman mechanics with swing-weave hardcasting  
    - Implemented swing-weave hardcasting logic in ShamanEnhancement.lua to optimize spell casting timing based on swing remains.  
    - Added new state expressions for main-hand and off-hand swing remains.  
    - Introduced configuration options for swing-weave hardcasts, instant cast stack thresholds, swing buffer, and latency cushion.  
    - Integrated LibClassicSwingTimerAPI for accurate swing timing.  
    - Updated embeds.xml to include the new swing timer library.  
    - Added new SimulationCraft priority files for Death Knight Frost and Unholy specs, including Festerblight variations.  
