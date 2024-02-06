classdef parser < handle
    % parser: parser class and C code generator
    % Written by Alfred in Nextlab
    %
    % User can add a configurable paramter by calling addArgument()
    % function, the inputs of the function are:
    %   argumentHeader: The header identifies the argument set
    %   format: The data type of the arguments, "int", "float", and
    %       "double" are supported. Use space to seperate multiple
    %       arguments. "string" is also allowed, but will be transfered to
    %       char string[256] in C
    %   argumentName: The name of the parameter. A single string and names
    %       for multiple arguments are sperated by space
    %   defaults: default value for all arguments, an array []
    %   unique: if the argument set is unique. If it is unique, the final
    %       value is determined by the last configuration; otherwise, an
    %       array will be created. string must be unique, cannot see any
    %       reason for a list of strings yet.
    %
    % For example, if you want to have a configuration about where the
    % sourse is injected (2D, row and col); the default location is (16,16),
    % then you can call:
    %   a = parser();
    %   a.addArgument("source_point", "int int", "src_row src_col", [16
    %   16], 0);
    % 
    % Once the parser is setup, you can pass an file name to "interpret"
    % function. The function will return a containers.Map object that can
    % be indexed by the argument name. It is quite slow to use the object
    % directly, in main script, create a local variable to receive it
    % first. For example:
    %   cfg = a.interpret("demo.cfg");
    %   src_row = cfg('src_row');
    %   src_col = cfg('src_col');
    %   clear cfg;
    % 
    % The generateC is a C++ code generator for C++ to use it. A header
    % file "parser.hpp" and a source file "parser.cpp" will be generated.
    %
    %
    % '#' can be used for writing comments, empty rows are allowed

    properties
        argumentHeaderList = {};
        argumentContextList = {};
    end

    methods
        function obj = parser()
            obj.argumentHeaderList = {};
            obj.argumentContextList = {};
        end

        function addArgument(obj, argumentHeader, format, argumentName, defaults, unique)
            % add a possible argument
            % remove blank at the head and the tail
            argumentHeader = strtrim(argumentHeader);
            format = strtrim(format); 
            argumentName = strtrim(argumentName);
            
            % record header
            obj.argumentHeaderList{end + 1} = argumentHeader;

            % format %d for integer, %f for float
            argumentsType = strsplit(format);
            argumentsCType = [];
            for i = 1:length(argumentsType)
                if strcmp(argumentsType{i}, 'int')
                    argumentsCType = [argumentsCType '%d'];
                elseif strcmp(argumentsType{i}, 'float')
                    argumentsCType = [argumentsCType '%f'];
                elseif strcmp(argumentsType{i}, 'double')
                    argumentsCType = [argumentsCType '%lf'];
                elseif strcmp(argumentsType{i}, 'string')
                    argumentsCType = [argumentsCType '%s'];
                    assert(unique == 1)
                end

                if i ~= length(argumentsType)
                    argumentsCType = [argumentsCType ' '];
                end
            end

            argumentNames = strsplit(argumentName);

            assert(length(argumentsType) == length(argumentNames));
            assert(length(argumentsType) == length(defaults));
            obj.argumentContextList{end + 1} = struct( ...
                   'argName' , argumentNames, ...
                   'argType' , argumentsType, ...
                   'argCType', argumentsCType, ...
                   'argVal' , [], ...
                   'counter' , 0, ...
                   'unique' , unique ...
               );

            for i = 1:length(argumentsType)
                if unique == 1
                    obj.argumentContextList{end}.argVal{end + 1} = defaults(i);
                else
                    obj.argumentContextList{end}.argVal{end + 1} = [defaults(i)];
                end
            end

        end

        function cfg = interpret(obj, fileName)
            fid = fopen(fileName, 'r');

            s = fgets(fid);
            while s~= -1
                s = strtrim(s);
                s = strsplit(s);
                if (length(s{1}) == 0) % ignore blank rows
                    s = fgets(fid);
                    continue;
                elseif (s{1}(1) == '#')    % ignroe comment rows
                    s = fgets(fid);
                    continue;
                end
                for i = 1:length(obj.argumentHeaderList)
                    

                    if strcmp(s{1}, obj.argumentHeaderList{i})
                        % f and d does not really matter in matlab
                        if (obj.argumentContextList{i}.unique)
                            for j = 1:length(obj.argumentContextList{i}.argName)
                                if strcmp(obj.argumentContextList{i}.argType{j}, "string")
                                    obj.argumentContextList{i}.argVal{j} = s{1 + j};
                                else
                                    obj.argumentContextList{i}.argVal{j} = str2num(s{1 + j});
                                end
                            end
                        else
                            obj.argumentContextList{i}.counter = obj.argumentContextList{i}.counter + 1;
                            for j = 1:length(obj.argumentContextList{i}.argName)
                                obj.argumentContextList{i}.argVal{j}(obj.argumentContextList{i}.counter) = str2num(s{1 + j});
                            end
                        end
                        break; % it only belongs to one header
                    end
                end

                s = fgets(fid);
            end

            fclose(fid);

            %% create returning cfgs
            cfg = containers.Map;
            disp('Configures got:')
            for i = 1:length(obj.argumentHeaderList)
                for j = 1:length(obj.argumentContextList{i}.argName)
                    cfg(obj.argumentContextList{i}.argName{j}) = obj.argumentContextList{i}.argVal{j};
                    fprintf("\t%s: ", obj.argumentContextList{i}.argName{j})
                    disp(obj.argumentContextList{i}.argVal{j})
                end
            end
        end

        function generateC(obj)
            headerFile = fopen("parser.hpp", "w");
            sourceFile = fopen("parser.cpp", "w");

            % generate header
            fprintf(headerFile, "#ifndef __PARSER_HPP__\n");
            fprintf(headerFile, "#define __PARSER_HPP__\n");
            fprintf(headerFile, "\n");
            fprintf(headerFile, "#include <stdio.h>\n");
            fprintf(headerFile, "#include <stdlib.h>\n");
            fprintf(headerFile, "#include <string.h>\n");
            fprintf(headerFile, "#include <vector>\n");
            fprintf(headerFile, "\nusing namespace std;\n");
            
            % create structure

            fprintf(headerFile, "\ntypedef struct{\n");
            for i = 1:length(obj.argumentHeaderList)
                for j = 1:length(obj.argumentContextList{i}.argName)
                    if (obj.argumentContextList{i}.unique)
                        if strcmp(obj.argumentContextList{i}.argType{j}, "string")
                            % The maximum filename length in Linux is 255
                            fprintf(headerFile, "\tchar %s[256];\n", obj.argumentContextList{i}.argName{j});
                        else
                            fprintf(headerFile, "\t%s %s;\n", obj.argumentContextList{i}.argType{j}, obj.argumentContextList{i}.argName{j});
                        end
                    else
                        fprintf(headerFile, "\tvector<%s> %s;\n", obj.argumentContextList{i}.argType{j}, obj.argumentContextList{i}.argName{j});
                    end
                end
            end
            fprintf(headerFile, "} userCfg;\n");

            % create function definition

            fprintf(headerFile, "\nint parseCfg(const char* fileName, userCfg& cfg);\n\n");
            fprintf(headerFile, "\nvoid showCfg(userCfg& cfg);\n\n");

            fprintf(headerFile, "#endif");

            % generate source function
            fprintf(sourceFile, "#include ""parser.hpp""\n\n");

            fprintf(sourceFile, "int parseCfg(const char* fileName, userCfg& cfg){\n");
            % set default value for unique scalers

            fprintf(sourceFile, "\n");
            for i = 1:length(obj.argumentHeaderList)
                for j = 1:length(obj.argumentContextList{i}.argName)
                    if (obj.argumentContextList{i}.unique)
                        if strcmp(obj.argumentContextList{i}.argType{j}, "string")
                            fprintf(sourceFile, "\tstrcpy(cfg.%s, ""%s"");\n", obj.argumentContextList{i}.argName{j}, num2str(obj.argumentContextList{i}.argVal{j}));
                        else
                            fprintf(sourceFile, "\tcfg.%s = %s;\n", obj.argumentContextList{i}.argName{j}, num2str(obj.argumentContextList{i}.argVal{j}));
                        end
                    end
                end
            end
            fprintf(sourceFile, "\n");

            
            % open file
            fprintf(sourceFile, "\tFILE* fp = fopen(fileName, ""r"");\n");
            fprintf(sourceFile, "\tif (fp == NULL){\n");
            fprintf(sourceFile, "\t\treturn -1;\n\t}\n");
            
            fprintf(sourceFile, "\tconst int buffer_depth = 1024;\n\n");
            fprintf(sourceFile, "\tchar buffer[buffer_depth];\n\n");
            fprintf(sourceFile, "\tchar temp_buf[256];\n\n");

            fprintf(sourceFile, "\twhile(!feof(fp)){\n");
            
            fprintf(sourceFile, "\t\tif (fgets(buffer, buffer_depth, fp) != NULL){\n");
            fprintf(sourceFile, "\t\t\tif ((buffer[0] == '#') || (buffer[0] == '\\n')){\n");
            fprintf(sourceFile, "\t\t\t\tcontinue;\n");
            fprintf(sourceFile, "\t\t\t}\n");

            fprintf(sourceFile, "\t\t\tsscanf(buffer, ""%%s"", temp_buf);\n");


            for i = 1:length(obj.argumentHeaderList)
                if i == 1
                    fprintf(sourceFile, "\t\t\tif(strcmp(temp_buf, ""%s"") == 0){\n", obj.argumentHeaderList{i});
                else
                    fprintf(sourceFile, "\t\t\telse if(strcmp(temp_buf, ""%s"") == 0){\n", obj.argumentHeaderList{i});
                end
                tempString = [];
                for j = 1:length(obj.argumentContextList{i}.argName)
                    if strcmp(obj.argumentContextList{i}.argType{j}, "string")
                        fprintf(sourceFile, "\t\t\t\tchar* %s = cfg.%s;\n", obj.argumentContextList{i}.argName{j}, obj.argumentContextList{i}.argName{j});
                        tempString = [tempString obj.argumentContextList{i}.argName{j}]; %#ok<*AGROW>
                    else
                        fprintf(sourceFile, "\t\t\t\t%s %s;\n", obj.argumentContextList{i}.argType{j},  obj.argumentContextList{i}.argName{j});
                        tempString = [tempString '&' obj.argumentContextList{i}.argName{j}]; %#ok<*AGROW>
                    end


                    if j ~= length(obj.argumentContextList{i}.argName)
                        tempString = [tempString ', '];
                    end
                end
                fprintf(sourceFile, "\t\t\t\tsscanf(buffer, ""%%s %s"", temp_buf, %s);\n", obj.argumentContextList{i}.argCType, tempString);
                
                for j = 1:length(obj.argumentContextList{i}.argName)
                    if (obj.argumentContextList{i}.unique)
                        if strcmp(obj.argumentContextList{i}.argType{j}, "string") == 0
                            fprintf(sourceFile, "\t\t\t\tcfg.%s = %s;\n", obj.argumentContextList{i}.argName{j},  obj.argumentContextList{i}.argName{j});
                        end
                    else
                        fprintf(sourceFile, "\t\t\t\tcfg.%s.push_back(%s);\n", obj.argumentContextList{i}.argName{j},  obj.argumentContextList{i}.argName{j});
                    end
                end
            
                fprintf(sourceFile, "\t\t\t}\n");
            end

            fprintf(sourceFile, "\t\t}\n");

            fprintf(sourceFile, "\t\telse{\n");
            fprintf(sourceFile, "\t\t\tbreak;\n");
            fprintf(sourceFile, "\t\t}\n");
            fprintf(sourceFile, "\t}\n");
            
            fprintf(sourceFile, "\tfclose(fp);\n");

            % put default values for non unique variables

            fprintf(sourceFile, "\n");
            for i = 1:length(obj.argumentHeaderList)
                for j = 1:length(obj.argumentContextList{i}.argName)
                    if (obj.argumentContextList{i}.unique == 0)
                        fprintf(sourceFile, "\tif (cfg.%s.empty()){\n", obj.argumentContextList{i}.argName{j});
                        fprintf(sourceFile, "\t\tcfg.%s.push_back(%s);\n", obj.argumentContextList{i}.argName{j}, num2str(obj.argumentContextList{i}.argVal{j}));
                        fprintf(sourceFile, "\t}\n");

                    end
                end
            end
            fprintf(sourceFile, "\n");

            fprintf(sourceFile, "\treturn 0;\n");
            fprintf(sourceFile, "}\n");

            % print function

            fprintf(sourceFile, "\nvoid showCfg(userCfg& cfg){\n");

            for i = 1:length(obj.argumentHeaderList)
                ctypePlaceHolder = strsplit(obj.argumentContextList{i}.argCType);
                for j = 1:length(obj.argumentContextList{i}.argName)
                    if (obj.argumentContextList{i}.unique)
                        fprintf(sourceFile, "\tprintf(""%s = %s;\\n"", cfg.%s);\n", obj.argumentContextList{i}.argName{j},  ctypePlaceHolder{j}, obj.argumentContextList{i}.argName{j});
                    else
                        fprintf(sourceFile, "\tfor (int i = 0;i < cfg.%s.size(); i++){\n", obj.argumentContextList{i}.argName{j});
                        fprintf(sourceFile, "\t\tprintf(""%s[%%d] = %s;\\n"", i, cfg.%s[i]);\n", obj.argumentContextList{i}.argName{j},  ctypePlaceHolder{j},  obj.argumentContextList{i}.argName{j});
                        fprintf(sourceFile, "\t}\n");
                    end
                end
            
            end

            fprintf(sourceFile, "}\n");
            


            fclose(headerFile);
            fclose(sourceFile);
        end
    end
end