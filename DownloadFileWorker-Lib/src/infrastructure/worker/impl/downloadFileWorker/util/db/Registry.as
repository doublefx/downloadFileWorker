package infrastructure.worker.impl.downloadFileWorker.util.db {
import domain.vo.DownloadFileDescriptor;

import flash.data.SQLResult;
import flash.data.SQLStatement;

public class Registry extends Database {

    private static const DB_DEF:String = "CREATE TABLE IF NOT EXISTS downloadingFiles (fileUrl TEXT, fileTargetPath TEXT, bytesLoaded NUMERIC, bytesTotal NUMERIC, PRIMARY KEY ( fileUrl, fileTargetPath));";

    private static var __initialized:Boolean;


    public static function initialize(dbPath:String, connectionName:String):void {
        if (Database.connect(dbPath, connectionName) && createDB())
            __initialized = true;
    }

    public static function close():void {
        Database.close();
    }

    public static function selectAll():Array {
        var files:Array;

        if (__initialized) {
            var sql:SQLStatement = new SQLStatement();
            sql.text = "SELECT * FROM downloadingFiles;";

            var result:SQLResult = Database.execute(sql);

            if (result.data) {
                trace("selectAll->rowsAffected: " + result.data.length);

                files = [];
                for each (var item:* in result.data) {
                    var fd:DownloadFileDescriptor = new DownloadFileDescriptor(item.fileurl, item.fileTarget);
                    fd.bytesLoaded = item.bytesLoaded;
                    fd.bytesTotal = item.bytesTotal;

                    files[files.length] = fd;
                }
            }
        }
        return files;
    }

    public static function load(fileDescriptor:DownloadFileDescriptor):void {
        if (__initialized) {
            var sql:SQLStatement = new SQLStatement();
            sql.text = "SELECT * FROM downloadingFiles WHERE fileUrl='" + fileDescriptor.fileUrl
                    + "' AND fileTargetPath='" + fileDescriptor.fileTargetPath + "';";

            var result:SQLResult = Database.execute(sql);

            if (result.data) {
                if (result.data.length > 0) {
                    fileDescriptor.bytesLoaded = result.data[0].bytesLoaded;
                    fileDescriptor.bytesTotal = result.data[0].bytesTotal;
                }
                trace("load->rowsAffected: " + result.data.length);
            }
        }
    }

    public static function save(fileDescriptor:DownloadFileDescriptor):void {
        if (__initialized) {
            var sql:SQLStatement = new SQLStatement();
            sql.text = "REPLACE INTO downloadingFiles (fileUrl, fileTargetPath, bytesLoaded, bytesTotal) VALUES ('"
                    + fileDescriptor.fileUrl
                    + "','" + fileDescriptor.fileTargetPath
                    + "'," + fileDescriptor.bytesLoaded
                    + "," + fileDescriptor.bytesTotal
                    + ");";

            var result:SQLResult = Database.execute(sql);

            if (result) {
                trace("save->rowsAffected: " + result.rowsAffected);
            }
        }
    }

    public static function remove(fileDescriptor:DownloadFileDescriptor):void {
        if (__initialized) {
            var sql:SQLStatement = new SQLStatement();
            sql.text = "DELETE FROM downloadingFiles WHERE fileUrl='" + fileDescriptor.fileUrl
                    + "' AND fileTargetPath='" + fileDescriptor.fileTargetPath + "';";

            var result:SQLResult = Database.execute(sql);

            if (result) {
                trace("remove->rowsAffected: " + result.rowsAffected);
            }
        }
    }

    private static function createDB():Boolean {
        var sql:SQLStatement = new SQLStatement();
        sql.text = DB_DEF;

        try {
            Database.execute(sql, true);
        } catch (error:Error) {
            traceError("createDB", error, sql.text);

            return false;
        }

        return true;
    }
}
}