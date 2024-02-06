#include "parser.hpp"
#include <stdio.h>


int main(int argc, char* argv[]){
    
    userCfg cfg;

    parseCfg("demo.cfg", cfg);
    
    showCfg(cfg);
    
    return 0;
}
