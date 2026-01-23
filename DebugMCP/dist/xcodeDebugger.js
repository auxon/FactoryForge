import { spawn } from 'child_process';
import { EventEmitter } from 'events';
export class XcodeDebugger extends EventEmitter {
    lldbProcess = null;
    isAttached = false;
    currentProcess = null;
    breakpoints = [];
    outputBuffer = [];
    commandQueue = [];
    currentLocation = null;
    constructor() {
        super();
        this.setupEventHandlers();
    }
    setupEventHandlers() {
        // Handle process events
        process.on('exit', () => {
            this.cleanup();
        });
        process.on('SIGINT', () => {
            this.cleanup();
        });
        process.on('SIGTERM', () => {
            this.cleanup();
        });
    }
    cleanup() {
        if (this.lldbProcess) {
            this.lldbProcess.kill('SIGTERM');
            this.lldbProcess = null;
        }
        this.isAttached = false;
        this.currentProcess = null;
    }
    async attachToProcess(pid, processName) {
        try {
            if (this.isAttached) {
                return { success: false, message: 'Already attached to a process. Detach first.' };
            }
            // Find process if name provided
            if (processName && !pid) {
                const foundPid = await this.findProcessByName(processName);
                if (foundPid === null) {
                    return { success: false, message: `Process "${processName}" not found` };
                }
                pid = foundPid;
            }
            if (!pid) {
                return { success: false, message: 'No process ID provided' };
            }
            // Start LLDB process
            const pidString = pid.toString();
            this.lldbProcess = spawn('lldb', ['-p', pidString], {
                stdio: ['pipe', 'pipe', 'pipe'],
                env: { ...process.env, TERM: 'dumb' }
            });
            return new Promise((resolve, reject) => {
                if (!this.lldbProcess) {
                    reject(new Error('Failed to start LLDB process'));
                    return;
                }
                const self = this;
                let outputBuffer = '';
                let errorBuffer = '';
                this.lldbProcess.stdout?.on('data', (data) => {
                    const output = data.toString();
                    outputBuffer += output;
                    self.outputBuffer.push(output);
                    // Check for successful attachment
                    if (output.includes('(lldb)')) {
                        self.isAttached = true;
                        self.currentProcess = { pid: pid, name: processName || `PID ${pid}` };
                        resolve({ success: true, message: `Successfully attached to process ${pid}` });
                    }
                });
                this.lldbProcess.stderr?.on('data', (data) => {
                    errorBuffer += data.toString();
                    console.error('LLDB stderr:', errorBuffer);
                });
                this.lldbProcess.on('close', (code) => {
                    self.isAttached = false;
                    if (code !== 0) {
                        reject(new Error(`LLDB process exited with code ${code}: ${errorBuffer}`));
                    }
                });
                this.lldbProcess.on('error', (error) => {
                    reject(new Error(`Failed to start LLDB: ${error.message}`));
                });
                // Timeout after 10 seconds
                setTimeout(() => {
                    reject(new Error('LLDB attachment timed out'));
                }, 10000);
            });
        }
        catch (error) {
            return {
                success: false,
                message: `Failed to attach: ${error instanceof Error ? error.message : String(error)}`
            };
        }
    }
    async findProcessByName(name) {
        return new Promise((resolve) => {
            const ps = spawn('ps', ['aux'], { stdio: ['pipe', 'pipe', 'pipe'] });
            let output = '';
            ps.stdout?.on('data', (data) => {
                output += data.toString();
            });
            ps.on('close', () => {
                const lines = output.split('\n');
                for (const line of lines) {
                    if (line.includes(name)) {
                        const parts = line.trim().split(/\s+/);
                        const pid = parseInt(parts[1]);
                        if (!isNaN(pid)) {
                            resolve(pid);
                            return;
                        }
                    }
                }
                resolve(null);
            });
            ps.on('error', () => {
                resolve(null);
            });
        });
    }
    async setBreakpoint(file, line, symbol, condition) {
        if (!this.isAttached || !this.lldbProcess) {
            return { success: false, message: 'Not attached to any process' };
        }
        try {
            let command;
            if (file && line) {
                command = `breakpoint set -f "${file}" -l ${line}`;
            }
            else if (symbol) {
                command = `breakpoint set -n "${symbol}"`;
            }
            else {
                return { success: false, message: 'Either file/line or symbol must be provided' };
            }
            if (condition) {
                command += ` -c "${condition}"`;
            }
            const result = await this.runLLDBCommand(command);
            // Parse breakpoint ID from output
            const match = result.output.match(/Breakpoint (\d+)/);
            const breakpointId = match ? parseInt(match[1]) : this.breakpoints.length + 1;
            this.breakpoints.push({
                id: breakpointId,
                file,
                line,
                symbol,
                enabled: true
            });
            return {
                success: true,
                breakpointId,
                message: `Breakpoint set at ${file ? `${file}:${line}` : symbol || 'unknown'}`
            };
        }
        catch (error) {
            return {
                success: false,
                message: `Failed to set breakpoint: ${error instanceof Error ? error.message : String(error)}`
            };
        }
    }
    async continueExecution() {
        return this.runLLDBCommand('continue');
    }
    async stepOver() {
        return this.runLLDBCommand('next');
    }
    async stepInto() {
        return this.runLLDBCommand('step');
    }
    async stepOut() {
        return this.runLLDBCommand('finish');
    }
    async inspectVariable(expression) {
        try {
            const result = await this.runLLDBCommand(`expression ${expression}`);
            return {
                success: true,
                value: result.output,
                message: `Value of ${expression}`
            };
        }
        catch (error) {
            return {
                success: false,
                message: `Failed to inspect variable: ${error instanceof Error ? error.message : String(error)}`
            };
        }
    }
    async getStackTrace() {
        try {
            const result = await this.runLLDBCommand('bt');
            // Parse stack trace
            const frames = this.parseStackTrace(result.output);
            return {
                success: true,
                frames,
                message: `Stack trace with ${frames.length} frames`
            };
        }
        catch (error) {
            return {
                success: false,
                message: `Failed to get stack trace: ${error instanceof Error ? error.message : String(error)}`
            };
        }
    }
    parseStackTrace(output) {
        const frames = [];
        const lines = output.split('\n');
        for (const line of lines) {
            // Parse frame format: "* frame #0: 0x0000000100003f29 App`main(argc=1, argv=0x00007ffeefbff5c8) at main.c:12:1"
            const match = line.match(/\* frame #(\d+): .*`([^`]+).* at ([^:]+):(\d+)/);
            if (match) {
                frames.push({
                    index: parseInt(match[1]),
                    function: match[2],
                    file: match[3],
                    line: parseInt(match[4])
                });
            }
        }
        return frames;
    }
    async listBreakpoints() {
        try {
            const result = await this.runLLDBCommand('breakpoint list');
            return {
                success: true,
                breakpoints: this.breakpoints,
                message: `Found ${this.breakpoints.length} breakpoints`
            };
        }
        catch (error) {
            return {
                success: false,
                breakpoints: [],
                message: `Failed to list breakpoints: ${error instanceof Error ? error.message : String(error)}`
            };
        }
    }
    async deleteBreakpoint(breakpointId) {
        try {
            const result = await this.runLLDBCommand(`breakpoint delete ${breakpointId}`);
            // Remove from our local list
            this.breakpoints = this.breakpoints.filter(bp => bp.id !== breakpointId);
            return {
                success: true,
                message: `Deleted breakpoint ${breakpointId}`
            };
        }
        catch (error) {
            return {
                success: false,
                message: `Failed to delete breakpoint: ${error instanceof Error ? error.message : String(error)}`
            };
        }
    }
    async runLLDBCommand(command) {
        if (!this.isAttached || !this.lldbProcess) {
            throw new Error('Not attached to any process');
        }
        return new Promise((resolve, reject) => {
            if (!this.lldbProcess?.stdin) {
                reject(new Error('LLDB stdin not available'));
                return;
            }
            let outputBuffer = '';
            let commandCompleted = false;
            const onData = (data) => {
                const chunk = data.toString();
                outputBuffer += chunk;
                // Check if command completed (LLDB prompt appears)
                if (chunk.includes('(lldb)')) {
                    commandCompleted = true;
                    cleanup();
                    resolve({
                        success: true,
                        output: outputBuffer,
                        message: 'Command executed successfully'
                    });
                }
            };
            const cleanup = () => {
                if (this.lldbProcess) {
                    this.lldbProcess.stdout?.off('data', onData);
                    this.lldbProcess.stderr?.off('data', onData);
                }
            };
            const onError = (error) => {
                cleanup();
                reject(error);
            };
            // Set up listeners
            this.lldbProcess.stdout?.on('data', onData);
            this.lldbProcess.stderr?.on('data', onData);
            // Send command
            this.lldbProcess.stdin.write(command + '\n');
            // Timeout after 30 seconds
            setTimeout(() => {
                if (!commandCompleted) {
                    cleanup();
                    reject(new Error(`Command timed out: ${command}`));
                }
            }, 30000);
        });
    }
    async getDebugStatus() {
        return {
            isAttached: this.isAttached,
            currentProcess: this.currentProcess || undefined,
            breakpoints: this.breakpoints,
            currentLocation: this.currentLocation || undefined,
            lastOutput: this.outputBuffer.slice(-10) // Last 10 output lines
        };
    }
    async detach() {
        try {
            if (!this.isAttached) {
                return { success: true, message: 'Not attached to any process' };
            }
            await this.runLLDBCommand('detach');
            this.cleanup();
            return { success: true, message: 'Successfully detached from process' };
        }
        catch (error) {
            this.cleanup();
            return {
                success: false,
                message: `Failed to detach: ${error instanceof Error ? error.message : String(error)}`
            };
        }
    }
}
