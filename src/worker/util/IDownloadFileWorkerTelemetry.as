package worker.util {

[Bindable]
public interface IDownloadFileWorkerTelemetry {

    /**
     * return the date & time this download started.
     */
    function get startTime():Date;

    /**
     * return the date & time this download ended.
     */
    function get endTime():Date;

    /**
     * return the total time this download took in milliseconds.
     */
    function get totalTime():Number;

    /**
     * return the total effective time this download took in milliseconds.
     */
    function get totalEffectiveTime():Number;

    /**
     * return the estimated remaining time this download took in milliseconds.
     */
    function get estimatedRemainingTime():Number;

    /**
     * return the average number of bytes per second this download is currently going.
     */
    function get numberOfBytesPerSecondAverage():Number;
}
}