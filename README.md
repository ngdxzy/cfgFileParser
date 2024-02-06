# Configuration File Parser

This project is to create a parser of a configuration file. The ultimate purpose was to make the configuration file work in Matlab, Python, and C++.

Since C++ is not a scripting language, it is less runtime reconfigurable. Therefore, both the Matlab class and the Python class have an ugly 'generateC' code generation function that can create `parser.hpp` and `parser.cpp`.


# Configuration Syntax

Any configuration must have a header, followed by one or several values. For simplicity, the meaning of the values is not listed in the configuration file. For example, if the configuration file wants to add a source point to a 2D space at a location (10, 20), the configuration entry should look like this:

```
source_point 10 20
```

The meaning of 
