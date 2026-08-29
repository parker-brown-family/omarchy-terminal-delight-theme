#version 320 es
// fixture: just enough MONITOR CONFIG for td-monitor's grammar
// ---- MONITOR CONFIG ----------------------------------------------------
#define ANIMATED 0              // 1 = motion
const float SCAN       = 0.22;  // scanline depth
const float TRACKING   = 0.00;  // rolling band strength
const float FLICKER    = 0.00;  // stepped burst depth
const float JIGGLE     = 0.00;  // rare hop
const float GLARE      = 0.00;  // whole-screen glare
// ---- END CONFIG --------------------------------------------------------
void main() {}
