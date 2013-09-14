package worker.util {
import flash.display.Sprite;

public class AbstractWorker extends Sprite {
    protected var workerName:String;

    public function AbstractWorker() {
        super();
        initialize();
    }

    protected function initialize():void {
        throw new Error("Don't class it directly but implement it in sub-classes");
    }
}
}