
class Logger{
    protected:
        int level;
    public:
        Logger(int lvl){
                 level = lvl;
             };
        ~Logger();

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