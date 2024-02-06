# Configuration File Parser

This project is to create a parser of a configuration file. The ultimate purpose was to make the configuration file work in Matlab, Python, and C++.

Since C++ is not a scripting language, it is less runtime reconfigurable. Therefore, both the Matlab class and the Python class have an ugly 'generateC' code generation function that can create `parser.hpp` and `parser.cpp`.


# Configuration Syntax

Any configuration must have a header, followed by one or several values. For simplicity, the meaning of the values is not listed in the configuration file. For example, if the configuration file wants to add a source point to a 2D space at a location (10, 20), the configuration entry should look like this:

```
source_point 10 20
```

The name of the values (10 and 20) is specified when setting the parser. '#' is allowed for writing comments in configuration files. The supported value types are integers, floating point numbers, and strings. If it is a string, it must be unique, which means it will only have one value 

# A demo

The configuration file is:

```
# demo.cfg
# only for debugging and testing

# ignore

nrow 512
ncol 1024

src_point 256 256

observation_point 256 768 4.1 0.33
observation_point 768 768 10.1 0.33
observation_point 767 256 0.1 0.33

binFileName helloWorld

nrow 1024

```

## Matlab reading codes

Firstly, instantiate an object of the `parser` object:

```matlab
cfgParser = parser();
```

Secondly, add configuration entries into the parser by calling the function `addArgument`. The `addArgument` function has 5 inputs:

1. Header name: The header in the configuration file, which is a string without any space. The parser looks for the header first.
2. Data type: The data type of the values following the header. The possible types are "int", "float", "double", and "string". The types should be placed in a single string separated by spaces such as "int float float". If the value is a string, then it cannot come with other values or another string.
3. Data name: The name (or the meaning) of the data. It is also a single string with multiple names of the values separated by space such as "source_row source_col"
4. Default values: The default value of the values. It is an array of values. If the value is a string, then it must be a single string here. It is recommended that always put a `[]` even when there is only a single value.
5. Unique: when the header is set as unique, then all the values following this header only get one final value in the configuration file. When the value is not set as unique, when multiple headers show up, the parser creates an array to return all received configurations.

To read the demo configurations, run the following code:

```matlab
cfgParser.addArgument("observation_point", "int int float float", "obs_row obs_col golden weight", [1, 1, 1 1], 0)
cfgParser.addArgument("src_point", "int int", "src_row src_col", [1, 1], 0);
cfgParser.addArgument("nrow", "int", "nrow", [11], 1)
cfgParser.addArgument("ncol", "int", "ncol", [12], 1)
cfgParser.addArgument("binFileName", "string", "binFileName", "c.bin", 1)
```

Thirdly, load the configuration file by calling the `interpret` function of the parser, it only takes the configuration file name.

```matlab
configs = cfgParser.interpret("demo.cfg");
```

The returning value is a Matlab container object that allows using a string to index it. Since it is slow to index with a string, it is recommended to define a value to receive a certain configuration as follows:

```matlab
obs_row = configs('obs_row')
obs_col = configs('obs_col')
```

Notice that if you only want to generate C++ files, do not call the `interpret` function or the default value may be changed after the configuration file is read.

## Python reading codes

The Python code is almost identical to the Matlab code. There are only 2 differences:
1. The default values when calling `addArgument` function must be enclosed in `[]`.
2. The return of `interpret` function is a Python dictionary. It is also indexed with strings.

The code that has exactly same function with the Matlab code is shown below:

```python
cfgParser = parser()
cfgParser.addArgument("observation_point", "int int float float", "obs_row obs_col golden weight", [1, 1, 1, 1], 0)
cfgParser.addArgument("src_point", "int int", "src_row src_col", [1, 1], 0)
cfgParser.addArgument("nrow", "int", "nrow", [11], 1)
cfgParser.addArgument("ncol", "int", "ncol", [12], 1)
cfgParser.addArgument("binFileName", "string", "binFileName", ["c.bin"], 1)

cfgParser.generateC()

cfg = cfgParser.interpret('demo.cfg')

print(cfg)
print(cfg['src_row'])
print(cfg['src_col'])
```

## C++ reading code

The Matlab/Python class can generate the files for C++ to use. In `parser.hpp` file, a `userCfg` structure is defined with all data that is added in the Matlab/Python code. If the value is not unique, then it will be a C++ vector for dynamic allocation. In addition, a `parseCfg` function is also defined for a user to load configurations from a file; a `showCfg` is defined to list all read configurations. The header file generated is shown below:

```c++
#ifndef __PARSER_HPP__
#define __PARSER_HPP__

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <vector>

using namespace std;

typedef struct{
	vector<int> obs_row;
	vector<int> obs_col;
	vector<float> golden;
	vector<float> weight;
	vector<int> src_row;
	vector<int> src_col;
	int nrow;
	int ncol;
	char binFileName[256];
} userCfg;

int parseCfg(const char* fileName, userCfg& cfg);


void showCfg(userCfg& cfg);

#endif

```

The two functions are implemented in `parser.cpp`. There is no need to read the parser.cpp at all as it is totally not generic. Everything in the generated C files is not generic at all.

A demo `main.cpp` is provided in the repository. It simply reads the `demo.cfg` and prints all received values. You can run it with the following commands in Linux (you have to generate the `parser.hpp` and `parser.cpp` first):

```bash
g++ *.cpp
./a.out
```
