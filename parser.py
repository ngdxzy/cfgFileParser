#!python3
# parser: parser class and C code generator
# Written by Alfred in Nextlab
#
# User can add a configurable paramter by calling addArgument()
# function, the inputs of the function are:
#   argumentHeader: The header identifies the argument set
#   format: The data type of the arguments, "int", "float", and
#       "double" are supported. Use space to seperate multiple
#       arguments. "string" is also allowed, but will be transfered to
#       char string[256] in C
#   argumentName: The name of the parameter. A single string and names
#       for multiple arguments are sperated by space
#   defaults: default value for all arguments, an array []
#   unique: if the argument set is unique. If it is unique, the final
#       value is determined by the last configuration; otherwise, an
#       array will be created. string must be unique, cannot see any
#       reason for a list of strings yet.
#
# For example, if you want to have a configuration about where the
# sourse is injected (2D, row and col); the default location is (16,16),
# then you can call:
#   a = parser();
#   a.addArgument("source_point", "int int", "src_row src_col", [16
#   16], 0);
#
# Once the parser is setup, you can pass an file name to "interpret"
# function. The function will return a containers.Map object that can
# be indexed by the argument name. It is quite slow to use the object
# directly, in main script, create a local variable to receive it
# first. For example:
#   cfg = a.interpret("demo.cfg");
#   src_row = cfg('src_row');
#   src_col = cfg('src_col');
#   clear cfg;
#
# The generateC is a C++ code generator for C++ to use it. A header
# file "parser.hpp" and a source file "parser.cpp" will be generated.
#
#
# '#' can be used for writing comments, empty rows are allowed


class parser:
    argumentHeaderList = []
    argumentContextList = []

    def __init__(self):
        self.argumentHeaderList = []
        self.argumentContextList = []

    def addArgument(self, argumentHeader, formats, argumentName, defaults, unique):
        # format is key word in python
        # delete empty stuff
        argumentHeader = argumentHeader.strip()
        formats = formats.strip()
        argumentName = argumentName.strip()

        # record header
        self.argumentHeaderList.append(argumentHeader)

        # solve types
        argumentsType = formats.split()
        argumentsCType = ''

        for t in argumentsType:
            if t == 'int':
                argumentsCType += '%d'
            elif t == 'float':
                argumentsCType += '%f'
            elif t == 'double':
                argumentsCType += '%lf'
            elif t == 'string':
                argumentsCType += '%s'

            argumentsCType += ' '

        argumentsCType = argumentsCType.strip()

        argumentNames = argumentName.split()

        assert(len(argumentsType) == len(argumentNames))
        if (len(argumentsType) != 1):
            assert(len(argumentsType) == len(defaults))

        self.argumentContextList.append(
            {
                'argName': argumentNames,
                'argType': argumentsType,
                'argCType': argumentsCType,
                'argVal': None,
                'counter': 0,
                'unique': unique
            }
        )

        if not unique:
            self.argumentContextList[-1]['argVal'] = []

        for i in range(len(argumentsType)):
            if unique:
                self.argumentContextList[-1]['argVal'] = [defaults[i]]
            else:
                self.argumentContextList[-1]['argVal'].append([defaults[i]])

    def interpret(self, fileName):
        fd = open(fileName, 'r')
        lines = fd.readlines()

        for s in lines:
            s = s.strip()
            s = s.split()
            # remove comments and empty lines
            # if the line is empty, line[0] will not be used due to 'or'
            if len(s) == 0 or s[0] == '#':
                continue
            for i in range(len(self.argumentHeaderList)):
                if self.argumentHeaderList[i] == s[0]:
                    if (self.argumentContextList[i]['unique']):
                        for j in range(len(self.argumentContextList[i]['argName'])):
                            if self.argumentContextList[i]['argType'][j] ==  "string":
                                self.argumentContextList[i]['argVal'][j]  = s[j + 1]
                            elif self.argumentContextList[i]['argType'][j]  ==  "int":
                                self.argumentContextList[i]['argVal'][j]  = int(s[j + 1])
                            else:
                                self.argumentContextList[i]['argVal'][j]  = float(s[j + 1])
                    else:
                        for j in range(len(self.argumentContextList[i]['argName'])):
                            # if first time show up, delete default value
                            if self.argumentContextList[i]['counter'] == 0:
                                self.argumentContextList[i]['argVal'][j] = []

                            if self.argumentContextList[i]['argType'][j]  ==  "string":
                                self.argumentContextList[i]['argVal'][j].append(s[j + 1])
                            elif self.argumentContextList[i]['argType'][j] ==  "int":
                                self.argumentContextList[i]['argVal'][j].append(int(s[j + 1]))
                            else:
                                self.argumentContextList[i]['argVal'][j].append(float(s[j + 1]))

                        self.argumentContextList[i]['counter'] += 1
                    break # it only belongs to one header
        fd.close()


        # export
        ret = dict()
        for i in range(len(self.argumentHeaderList)):
            for j in range(len(self.argumentContextList[i]['argName'])):
                ret[self.argumentContextList[i]['argName'][j]] = self.argumentContextList[i]['argVal'][j]
        return ret

    def generateC(self):
        headerFile = open('parser.hpp', 'w')
        sourceFile = open('parser.cpp', 'w')

        # generate header
        headerFile.write("#ifndef __PARSER_HPP__\n")
        headerFile.write("#define __PARSER_HPP__\n")
        headerFile.write("\n")
        headerFile.write("#include <stdio.h>\n")
        headerFile.write("#include <stdlib.h>\n")
        headerFile.write("#include <string.h>\n")
        headerFile.write("#include <vector>\n")
        headerFile.write("\nusing namespace std;\n")

        # create structure

        headerFile.write("\ntypedef struct{\n")
        for i in range(len(self.argumentHeaderList)):
            for j in range(len(self.argumentContextList[i]['argName'])):
                if (self.argumentContextList[i]['unique']):
                    if self.argumentContextList[i]['argType'][j] == "string":
                        # The maximum filename len in Linux is 255
                        headerFile.write("\tchar %s[256];\n" % (self.argumentContextList[i]['argName'][j]))
                    else:
                        headerFile.write("\t%s %s;\n" % (self.argumentContextList[i]['argType'][j], self.argumentContextList[i]['argName'][j]))

                else:
                    headerFile.write("\tvector<%s> %s;\n" % (self.argumentContextList[i]['argType'][j], self.argumentContextList[i]['argName'][j]))



        headerFile.write("} userCfg;\n")

        # create function definition

        headerFile.write("\nint parseCfg(const char* fileName, userCfg& cfg);\n\n")
        headerFile.write("\nvoid showCfg(userCfg& cfg);\n\n")

        headerFile.write("#endif")
        headerFile.close()

        # generate source function
        sourceFile.write("#include \"parser.hpp\"\n\n")

        sourceFile.write("int parseCfg(const char* fileName, userCfg& cfg){\n")
        # set default value for unique scalers

        sourceFile.write("\n")
        for i in range(len(self.argumentHeaderList)):
            for j in range(len(self.argumentContextList[i]['argName'])):
                if (self.argumentContextList[i]['unique']):
                    if self.argumentContextList[i]['argType'][j] == "string":
                        sourceFile.write("\tstrcpy(cfg.%s, \"%s\");\n" % (self.argumentContextList[i]['argName'][j], str(self.argumentContextList[i]['argVal'][j])))
                    else:
                        sourceFile.write("\tcfg.%s = %s;\n" % (self.argumentContextList[i]['argName'][j], str(self.argumentContextList[i]['argVal'][j])))




        sourceFile.write("\n")


        # open file
        sourceFile.write("\tFILE* fp = fopen(fileName, \"r\");\n")
        sourceFile.write("\tif (fp == NULL){\n")
        sourceFile.write("\t\treturn -1;\n\t}\n")

        sourceFile.write("\tconst int buffer_depth = 1024;\n\n")
        sourceFile.write("\tchar buffer[buffer_depth];\n\n")
        sourceFile.write("\tchar temp_buf[256];\n\n")

        sourceFile.write("\twhile(!feof(fp)){\n")

        sourceFile.write("\t\tif (fgets(buffer, buffer_depth, fp) != NULL){\n")
        sourceFile.write("\t\t\tif ((buffer[0] == '#') || (buffer[0] == '\\n')){\n")
        sourceFile.write("\t\t\t\tcontinue;\n")
        sourceFile.write("\t\t\t}\n")

        sourceFile.write("\t\t\tsscanf(buffer, \"%s\", temp_buf);\n" % '%s')


        for i in range(len(self.argumentHeaderList)):
            if i == 0:
                sourceFile.write("\t\t\tif(strcmp(temp_buf, \"%s\") == 0){\n" % (self.argumentHeaderList[i]))
            else:
                sourceFile.write("\t\t\telse if(strcmp(temp_buf, \"%s\") == 0){\n" % (self.argumentHeaderList[i]))

            tempString = ''
            for j in range(len(self.argumentContextList[i]['argName'])):
                if self.argumentContextList[i]['argType'][j] ==  "string":
                    sourceFile.write("\t\t\t\tchar* %s = cfg.%s;\n" % (self.argumentContextList[i]['argName'][j], self.argumentContextList[i]['argName'][j]))
                    tempString += self.argumentContextList[i]['argName'][j]
                else:
                    sourceFile.write("\t\t\t\t%s %s;\n" % (self.argumentContextList[i]['argType'][j],  self.argumentContextList[i]['argName'][j]))
                    tempString +=  '&'
                    tempString +=  self.argumentContextList[i]['argName'][j]


                if j != len(self.argumentContextList[i]['argName']) - 1:
                    tempString +=  ', '


            sourceFile.write("\t\t\t\tsscanf(buffer, \"%%s %s\", temp_buf, %s);\n" % (self.argumentContextList[i]['argCType'], tempString))

            for j in range(len(self.argumentContextList[i]['argName'])):
                if (self.argumentContextList[i]['unique']):
                    if self.argumentContextList[i]['argType'][j] !=  "string":
                        sourceFile.write("\t\t\t\tcfg.%s = %s;\n" % (self.argumentContextList[i]['argName'][j],  self.argumentContextList[i]['argName'][j]))
                else:
                    sourceFile.write("\t\t\t\tcfg.%s.push_back(%s);\n" % (self.argumentContextList[i]['argName'][j],  self.argumentContextList[i]['argName'][j]))



            sourceFile.write("\t\t\t}\n")


        sourceFile.write("\t\t}\n")

        sourceFile.write("\t\telse{\n")
        sourceFile.write("\t\t\tbreak;\n")
        sourceFile.write("\t\t}\n")
        sourceFile.write("\t}\n")

        sourceFile.write("\tfclose(fp);\n")

        # put default values for non unique variables

        sourceFile.write("\n")
        for i in range(len(self.argumentHeaderList)):
            for j in range(len(self.argumentContextList[i]['argName'])):
                if (self.argumentContextList[i]['unique'] == 0):
                    sourceFile.write("\tif (cfg.%s.empty()){\n" % (self.argumentContextList[i]['argName'][j]))
                    sourceFile.write("\t\tcfg.%s.push_back(%s);\n" % (self.argumentContextList[i]['argName'][j], str(self.argumentContextList[i]['argVal'][j][0])))
                    sourceFile.write("\t}\n")

        sourceFile.write("\n")

        sourceFile.write("\treturn 0;\n")
        sourceFile.write("}\n")

        # print function

        sourceFile.write("\nvoid showCfg(userCfg& cfg){\n")

        for i in range(len(self.argumentHeaderList)):
            ctypePlaceHolder = self.argumentContextList[i]['argCType'].split()
            for j in range(len(self.argumentContextList[i]['argName'])):
                if (self.argumentContextList[i]['unique']):
                    sourceFile.write("\tprintf(\"%s = %s;\\n\", cfg.%s);\n" % (self.argumentContextList[i]['argName'][j],  ctypePlaceHolder[j], self.argumentContextList[i]['argName'][j]))
                else:
                    sourceFile.write("\tfor (int i = 0;i < cfg.%s.size(); i++){\n" % (self.argumentContextList[i]['argName'][j]))
                    sourceFile.write("\t\tprintf(\"%s[%%d] = %s;\\n\", i, cfg.%s[i]);\n" % (self.argumentContextList[i]['argName'][j],  ctypePlaceHolder[j],  self.argumentContextList[i]['argName'][j]))
                    sourceFile.write("\t}\n")

        sourceFile.write("}\n")

        sourceFile.close()

if __name__ == '__main__':
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
