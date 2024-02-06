clear
clc

a = parser();
a.addArgument("observation_point", "int int float float", "obs_row obs_col golden weight", [1, 1, 1 1], 0)
a.addArgument("src_point", "int int", "src_row src_col", [1, 1], 0);
a.addArgument("nrow", "int", "nrow", [11], 1)
a.addArgument("ncol", "int", "ncol", [12], 1)
a.addArgument("binFileName", "string", "binFileName", "c.bin", 1)

a.generateC()

configs = a.interpret("demo.cfg");

obs_row = configs('obs_row')
obs_col = configs('obs_col')