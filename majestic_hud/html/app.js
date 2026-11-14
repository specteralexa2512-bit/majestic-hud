const hud = document.getElementById('hud');
const speedometer = document.getElementById('speedometer');

const setBar = (id, value) => {
    const element = document.getElementById(id);
    element.style.width = `${Math.max(0, Math.min(100, Number(value) || 0))}%`;
};

const formatMoney = value =>
    new Intl.NumberFormat('de-DE').format(Number(value) || 0);

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action !== 'update') return;

    hud.style.display = 'block';
    document.getElementById('player-id').textContent = data.id ?? 0;
    document.getElementById('job').textContent =
        `${data.job || 'Arbeitslos'}${data.grade ? ' • ' + data.grade : ''}`;
    document.getElementById('cash').textContent = formatMoney(data.cash);
    document.getElementById('bank').textContent = formatMoney(data.bank);

    setBar('health', data.health);
    setBar('armor', data.armor);
    setBar('hunger', data.hunger);
    setBar('thirst', data.thirst);

    speedometer.style.display = data.inVehicle ? 'block' : 'none';
    document.getElementById('speed').textContent = data.speed ?? 0;
    document.getElementById('fuel').textContent = data.fuel ?? 0;
});
