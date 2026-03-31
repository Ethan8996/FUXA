const assert = require('node:assert/strict');

const modbusSerial = require('modbus-serial');
const modbusDriver = require('../../runtime/devices/modbus');

describe('Modbus driver JSON import compatibility', () => {
    const originalReadHoldingRegisters = modbusSerial.prototype.readHoldingRegisters;

    afterEach(() => {
        modbusSerial.prototype.readHoldingRegisters = originalReadHoldingRegisters;
    });

    function createLogger() {
        return {
            errors: [],
            warnings: [],
            info() { },
            warn(message) {
                this.warnings.push(String(message));
            },
            error(message) {
                this.errors.push(String(message));
            }
        };
    }

    function createRuntime() {
        return {
            socketMutex: new Map(),
            scriptsMgr: {
                async runScript() {
                    return Buffer.alloc(0);
                }
            }
        };
    }

    function createDevice(tagType) {
        return {
            id: 'dev-1',
            name: 'Cdu',
            enabled: true,
            type: 'ModbusTCP',
            polling: 1000,
            property: {
                address: '127.0.0.1:565',
                slaveid: '1',
                delay: 0
            },
            tags: {
                tag1: {
                    id: 'tag1',
                    name: 'Tag 1',
                    type: tagType,
                    memaddress: '400000',
                    address: '10',
                    format: 0,
                    daq: {
                        enabled: false,
                        interval: 0,
                        changed: false,
                        restored: false
                    }
                }
            }
        };
    }

    it('normalizes generic imported number tags before polling', async () => {
        const calls = [];
        modbusSerial.prototype.readHoldingRegisters = function (start, size) {
            calls.push({ start, size });
            return Promise.resolve({ data: null, buffer: Buffer.alloc(0) });
        };

        const logger = createLogger();
        const driver = modbusDriver.create(createDevice('number'), logger, { emit() { } }, null, createRuntime());
        driver.init(modbusDriver.ModbusTypes.TCP);
        driver.load(createDevice('number'));

        await driver.polling();

        assert.deepEqual(calls, [{ start: 9, size: 1 }]);
        assert.equal(logger.errors.length, 0);
        assert.equal(logger.warnings.length, 1);
        assert.match(logger.warnings[0], /normalized to 'UInt16'/i);
    });

    it('normalizes generic imported bool tags before polling', async () => {
        const calls = [];
        modbusSerial.prototype.readHoldingRegisters = function (start, size) {
            calls.push({ start, size });
            return Promise.resolve({ data: null, buffer: Buffer.alloc(0) });
        };

        const logger = createLogger();
        const driver = modbusDriver.create(createDevice('bool'), logger, { emit() { } }, null, createRuntime());
        driver.init(modbusDriver.ModbusTypes.TCP);
        driver.load(createDevice('bool'));

        await driver.polling();

        assert.deepEqual(calls, [{ start: 9, size: 1 }]);
        assert.equal(logger.errors.length, 0);
        assert.equal(logger.warnings.length, 1);
        assert.match(logger.warnings[0], /normalized to 'Bool'/i);
    });

    it('skips unsupported imported tag types instead of polling sentinel addresses', async () => {
        const calls = [];
        modbusSerial.prototype.readHoldingRegisters = function (start, size) {
            calls.push({ start, size });
            return Promise.resolve({ data: null, buffer: Buffer.alloc(0) });
        };

        const logger = createLogger();
        const driver = modbusDriver.create(createDevice('numberish'), logger, { emit() { } }, null, createRuntime());
        driver.init(modbusDriver.ModbusTypes.TCP);
        driver.load(createDevice('numberish'));

        await driver.polling();

        assert.deepEqual(calls, []);
        assert.equal(logger.errors.length, 1);
        assert.match(logger.errors[0], /unsupported tag type/i);
    });
});
