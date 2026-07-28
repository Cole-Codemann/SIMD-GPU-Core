`ifndef CONFIG_VH
`define CONFIG_VH

//==================================
// Toggle features
//==================================
`define MEASURE_ATTRIBUTES
`define DEBUG_ATTRIBUTES

//==================================
// Attribute macros
//==================================
`ifdef MEASURE_ATTRIBUTES
    `define MEASURE (* mark_debug = "true" *)
`else
    `define MEASURE
`endif

`ifdef DEBUG_ATTRIBUTES
    `define DEBUG (* mark_debug = "true" *)
`else
    `define DEBUG
`endif

`endif