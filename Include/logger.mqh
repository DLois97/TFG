#property copyright "Copyright 2023, Daniel Lois Nuevo"
#property link      "https://github.com/DLois97"
#property version   "1.0"

class Logger{
    protected:
        int level;
    public:
        Logger(int lvl){
                 level = lvl;
             };
        Logger(){
            level = 1;
        };

        void info(string msg){
                if(level >= 1){
                    Print("[INFO] " + msg);
                }
            };
        void debug(string msg){
                if(level >= 2){
                    Print("[DEBUG] " + msg);
                }
            };
        void error(string msg){
                if(level >= 0){
                    Print("[ERROR] " + msg);
                }
            };

};