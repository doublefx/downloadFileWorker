package infrastructure.worker.api {
import flash.display.Sprite;
import flash.errors.IllegalOperationError;

public class AbstractWorker extends Sprite {

    protected var workerName:String;

    public function AbstractWorker(protectedConstructor:AbstractWorker) {
        super();

        if (protectedConstructor != this)
            throw new TypeError("Error #1007: Instantiation attempted on a non-constructor.", 1007);

        initialize();
    }

    protected function initialize():void {
        throw new IllegalOperationError("Must be overrided in sub-classes");
    }
}
}