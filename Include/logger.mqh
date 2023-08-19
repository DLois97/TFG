
class Logger{
    protected:
        int level;
    public:
        Logger(int level);
        ~Logger();

        void info(string msg);
        void debug(string msg);
        void error(string msg);

    Logger::Logger( int lvl){
        level = lvl;
    }

    void Logger::info(string msg){
        if(level >= 1){
            Print("[INFO] " + msg);
        }
    }

    void Logger::debug(string msg){
        if(level >= 2){
            Print("[DEBUG] " + msg);
        }
    }

    void Logger::error(string msg){
        if(level >= 0){
            Print("[ERROR] " + msg);
        }
    }


}