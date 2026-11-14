const hud = document.getElementById('hud');
const speedometer = document.getElementById('speedometer');
const speedElement = document.getElementById('speed');
const rpmElement = document.getElementById('rpm');
let targetSpeed = 0;
let shownSpeed = 0;
let lastDrawnSpeed = -1;
let lastFrameTime = 0;
let inVehicle = false;

const clamp = (value, min = 0, max = 100) => Math.max(min, Math.min(max, Number(value) || 0));
const moneyFormatter = new Intl.NumberFormat('de-DE', { maximumFractionDigits: 0 });
const timeFormatter = new Intl.DateTimeFormat('de-DE', { timeZone: 'Europe/Berlin', hour: '2-digit', minute: '2-digit', hour12: false });
const dateFormatter = new Intl.DateTimeFormat('de-DE', { timeZone: 'Europe/Berlin', day: '2-digit', month: '2-digit', year: 'numeric' });
const weekdayFormatter = new Intl.DateTimeFormat('de-DE', { timeZone: 'Europe/Berlin', weekday: 'long' });

function updateGermanDateTime() {
    const now = new Date();
    document.getElementById('clock').textContent = timeFormatter.format(now);
    document.getElementById('date').textContent = dateFormatter.format(now);
    const weekday = weekdayFormatter.format(now);
    document.getElementById('weekday').textContent = weekday.charAt(0).toUpperCase() + weekday.slice(1);
}

function animateTacho(timestamp) {
    if (inVehicle) {
        const delta = lastFrameTime ? Math.min((timestamp - lastFrameTime) / 1000, 0.05) : 0.016;
        lastFrameTime = timestamp;
        shownSpeed += (targetSpeed - shownSpeed) * (1 - Math.exp(-12 * delta));
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

updateGermanDateTime();
setInterval(updateGermanDateTime, 1000);
requestAnimationFrame(animateTacho);

window.addEventListener('message', ({ data }) => {
    if (!data || !data.action) return;

    if (data.action === 'playerUpdate') {
        hud.style.display = 'block';
        document.getElementById('online').textContent = data.online ?? 0;
        document.getElementById('player-id').textContent = data.id ?? 0;
        document.getElementById('player-id-copy').textContent = data.id ?? 0;
        document.getElementById('job').textContent = `${data.job || 'Arbeitslos'}${data.grade ? ` • ${data.grade}` : ''}`;
        document.getElementById('cash').textContent = moneyFormatter.format(Number(data.cash) || 0);
        document.getElementById('bank').textContent = moneyFormatter.format(Number(data.bank) || 0);
        document.getElementById('weather-label').textContent = data.weather || 'Wetter';
        document.getElementById('temperature').textContent = `${Math.round(Number(data.temperature) || 0)}°`;
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
        document.getElementById('fuel').textContent = Math.round(clamp(data.fuel));
        rpmElement.style.width = `${clamp((Number(data.rpm) || 0) * 100)}%`;
    }
});
