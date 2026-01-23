import { EventEmitter } from 'events';
export interface DebugStatus {
    isAttached: boolean;
    currentProcess?: {
        pid: number;
        name: string;
    };
    breakpoints: Array<{
        id: number;
        file?: string;
        line?: number;
        symbol?: string;
        enabled: boolean;
    }>;
    currentLocation?: {
        file: string;
        line: number;
        function: string;
    };
    lastOutput: string[];
}
export declare class XcodeDebugger extends EventEmitter {
    private lldbProcess;
    private isAttached;
    private currentProcess;
    private breakpoints;
    private outputBuffer;
    private commandQueue;
    private currentLocation;
    constructor();
    private setupEventHandlers;
    private cleanup;
    attachToProcess(pid?: number, processName?: string): Promise<{
        success: boolean;
        message: string;
    }>;
    private findProcessByName;
    setBreakpoint(file?: string, line?: number, symbol?: string, condition?: string): Promise<{
        success: boolean;
        breakpointId?: number;
        message: string;
    }>;
    continueExecution(): Promise<{
        success: boolean;
        message: string;
    }>;
    stepOver(): Promise<{
        success: boolean;
        message: string;
    }>;
    stepInto(): Promise<{
        success: boolean;
        message: string;
    }>;
    stepOut(): Promise<{
        success: boolean;
        message: string;
    }>;
    inspectVariable(expression: string): Promise<{
        success: boolean;
        value?: string;
        message: string;
    }>;
    getStackTrace(): Promise<{
        success: boolean;
        frames?: Array<{
            index: number;
            function: string;
            file: string;
            line: number;
        }>;
        message: string;
    }>;
    private parseStackTrace;
    listBreakpoints(): Promise<{
        success: boolean;
        breakpoints: Array<{
            id: number;
            file?: string;
            line?: number;
            symbol?: string;
            enabled: boolean;
        }>;
        message: string;
    }>;
    deleteBreakpoint(breakpointId: number): Promise<{
        success: boolean;
        message: string;
    }>;
    runLLDBCommand(command: string): Promise<{
        success: boolean;
        output: string;
        message: string;
    }>;
    getDebugStatus(): Promise<DebugStatus>;
    detach(): Promise<{
        success: boolean;
        message: string;
    }>;
}
