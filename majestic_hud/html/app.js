const hud = document.getElementById('hud');
const speedometer = document.getElementById('speedometer');
const speedElement = document.getElementById('speed');
const fuelElement = document.getElementById('fuel');
const rpmElement = document.getElementById('rpm');

let targetSpeed = 0;
let shownSpeed = 0;
let lastDrawnSpeed = -1;
let lastFrameTime = 0;
let inVehicle = false;

const clamp = (value, min = 0, max = 100) => Math.max(min, Math.min(max, Number(value) || 0));
const formatMoney = value => new Intl.NumberFormat('de-DE').format(Number(value) || 0);

function setBar(id, value) {
    const element = document.getElementById(id);
    if (element) element.style.width = `${clamp(value)}%`;
}

function animateTacho(timestamp) {
    if (inVehicle) {
        const delta = lastFrameTime ? Math.min((timestamp - lastFrameTime) / 1000, 0.05) : 0.016;
        lastFrameTime = timestamp;
        const blend = 1 - Math.exp(-12 * delta);
        shownSpeed += (targetSpeed - shownSpeed) * blend;
        const roundedSpeed = Math.round(shownSpeed);
        if (roundedSpeed !== lastDrawnSpeed) {
            speedElement.textContent = roundedSpeed;
            lastDrawnSpeed = roundedSpeed;
        }
    } else {
        lastFrameTime = 0;
    }
    requestAnimationFrame(animateTacho);
}
requestAnimationFrame(animateTacho);

window.addEventListener('message', ({ data }) => {
    if (!data || !data.action) return;

    if (data.action === 'playerUpdate') {
        hud.style.display = 'block';
        document.getElementById('online').textContent = data.online ?? 0;
        document.getElementById('player-id').textContent = data.id ?? 0;
        document.getElementById('player-id-copy').textContent = data.id ?? 0;
        document.getElementById('job').textContent = `${data.job || 'Arbeitslos'}${data.grade ? ` • ${data.grade}` : ''}`;
        document.getElementById('cash').textContent = formatMoney(data.cash);
        document.getElementById('bank').textContent = formatMoney(data.bank);
        document.getElementById('clock').textContent = `${String(data.hour ?? 0).padStart(2, '0')}:${String(data.minute ?? 0).padStart(2, '0')}`;
        setBar('health', data.health);
        setBar('armor', data.armor);
        setBar('hunger', data.hunger);
        setBar('thirst', data.thirst);
        return;
    }

    if (data.action === 'vehicleUpdate') {
        inVehicle = Boolean(data.inVehicle);
        speedometer.style.display = inVehicle ? 'block' : 'none';

        if (!inVehicle) {
            targetSpeed = 0;
            shownSpeed = 0;
            lastDrawnSpeed = -1;
            speedElement.textContent = '0';
            rpmElement.style.width = '0%';
            return;
        }

        targetSpeed = clamp(data.speed, 0, 999);
        document.getElementById('gear').textContent = data.gear ?? 'N';
        fuelElement.textContent = Math.round(clamp(data.fuel));
        rpmElement.style.width = `${clamp((Number(data.rpm) || 0) * 100)}%`;
    }
});
