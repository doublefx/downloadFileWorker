package domain.vo {
[Bindable]
public class DownloadFileDescriptor {
    public var fileUrl:String;
    public var fileTargetPath:String;
    public var progressPrecision:uint;
    public var bytesLoaded:Number;
    public var bytesTotal:Number;

    public function DownloadFileDescriptor(fileUrl:String = null, fileTarget:String = null, progressPrecision:uint = 0) {
        this.fileUrl = fileUrl;
        this.fileTargetPath = fileTarget;
        this.progressPrecision = progressPrecision;
    }
}
}