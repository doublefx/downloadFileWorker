package infrastructure.worker.impl.downloadFileWorker.util.db {
import flash.data.SQLConnection;
import flash.data.SQLResult;
import flash.data.SQLStatement;
import flash.filesystem.File;

public class Database {

    protected static var __dbPath:String;
    private static var __conn:SQLConnection;

    public static function connect(dbPath:String, throwError:Boolean = false):Boolean {
        var result:Boolean;

        if (!__conn) {
            __dbPath = dbPath;
            trace("Connecting async DB: " + dbPath);
            __conn = new SQLConnection();

            // The database file is in the application storage directory
            var dbFile:File = new File(dbPath);

            try {
                __conn.open(dbFile);
                result = true;
                trace("the database was created / opened successfully.");
            } catch (error:Error) {
                if (throwError)
                    throw error;
                else {
                    traceError("connect", error);
                }
            }
        } else result = true;

        return result;
    }

    public static function close():void {
        if (__conn) {
            __conn.close();
            __conn = null;
        }
    }

    public static function execute(stmt:SQLStatement, throwError:Boolean = false):SQLResult {
        stmt.sqlConnection = __conn;
        var result:SQLResult;

        try {
            stmt.execute();
            trace("SQL: " + stmt.text + " has been executed successfully.");

            result = stmt.getResult();

        } catch (error:Error) {
            if (throwError)
                throw error;
            else {
                traceError("execute", error, stmt.text);
            }
        }

        return result;
    }

    protected static function traceError(fctName:String, error:Error, sql:String = null):void {
        trace("function name: " + fctName + (sql != null) ? " SQL: " + sql : "");
        trace("Error message:", error.message);

        if (error["details"])
            trace("Details:", error["details"]);
    }
}
}
