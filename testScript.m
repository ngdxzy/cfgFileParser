clear
clc

cfgParser = parser();
cfgParser.addArgument("observation_point", "int int float float", "obs_row obs_col golden weight", [1, 1, 1 1], 0)
cfgParser.addArgument("src_point", "int int", "src_row src_col", [1, 1], 0);
cfgParser.addArgument("nrow", "int", "nrow", [11], 1)
cfgParser.addArgument("ncol", "int", "ncol", [12], 1)
cfgParser.addArgument("binFileName", "string", "binFileName", "c.bin", 1)

cfgParser.generateC()

configs = cfgParser.interpret("demo.cfg");

obs_row = configs('obs_row')
obs_col = configs('obs_col')