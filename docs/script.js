document.addEventListener('DOMContentLoaded', async () => {
    
    const REPO_OWNER = 'ahmed-majija';
    const REPO_NAME = 'nas_alkhir_reggane';
    const API_URL = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest`;

    const versionInfo = document.getElementById('versionInfo');
    const loadingSpinner = document.getElementById('loading-spinner');
    const errorMsg = document.getElementById('error-message');
    const mainDownloadBtn = document.getElementById('btn-main-download');

    // =========================================
    //  حركات الظهور عند التمرير (Intersection Observer)
    // =========================================
    const fadeElements = document.querySelectorAll('.fade-in');
    const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry, index) => {
            if (entry.isIntersecting) {
                setTimeout(() => {
                    entry.target.classList.add('visible');
                }, index * 80);
                observer.unobserve(entry.target);
            }
        });
    }, { threshold: 0.15, rootMargin: '0px 0px -40px 0px' });

    fadeElements.forEach(el => observer.observe(el));

    // =========================================
    //  مشهد ما بعد التحميل (Cinematic Celebration)
    // =========================================
    mainDownloadBtn.addEventListener('click', (e) => {
        if (mainDownloadBtn.classList.contains('disabled')) {
            e.preventDefault();
            return;
        }
        // اعرض المشهد السينمائي بعد لحظة
        setTimeout(() => {
            showCelebration();
        }, 400);
    });

    // =========================================
    //  جلب أحدث إصدار من GitHub
    // =========================================
    try {
        const response = await fetch(API_URL);
        
        if (!response.ok) {
            throw new Error('لا يوجد إصدارات عامة متاحة بعد.');
        }

        const data = await response.json();
        
        versionInfo.innerHTML = `<i class="fa-solid fa-circle-check" style="color: var(--emerald-primary);"></i> الإصدار الأحدث: ${data.tag_name} | صدر في: ${new Date(data.published_at).toLocaleDateString('ar-EG')}`;
        versionInfo.style.color = 'var(--emerald-primary)';

        let foundAsset = false;

        if (data.assets && data.assets.length > 0) {
            for (const asset of data.assets) {
                if (asset.name.toLowerCase().endsWith('.apk')) {
                    mainDownloadBtn.href = asset.browser_download_url;
                    mainDownloadBtn.classList.remove('disabled');
                    mainDownloadBtn.style.background = '';
                    foundAsset = true;
                    break;
                }
            }
        }

        loadingSpinner.style.display = 'none';

        if (!foundAsset) {
            errorMsg.style.display = 'flex';
            errorMsg.querySelector('span').textContent = 'الإصدار موجود، لكن لم يتم رفع النسخة القابلة للتحميل بعد.';
        }

    } catch (error) {
        loadingSpinner.style.display = 'none';
        errorMsg.style.display = 'flex';
        
        versionInfo.textContent = 'في انتظار أول إصدار (Release)';
        versionInfo.style.color = 'var(--text-muted)';
        
        console.error("خطأ في جلب الإصدار:", error);
    }
});

// =========================================
//  نظام الجزيئات الذهبية (Golden Particles)
// =========================================
let particleAnimationId = null;

function initParticles() {
    const canvas = document.getElementById('particlesCanvas');
    if (!canvas) return;
    
    const ctx = canvas.getContext('2d');
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    const particles = [];
    const particleCount = 70;
    const colors = [
        'rgba(198, 165, 71, 0.6)',   // ذهبي
        'rgba(198, 165, 71, 0.3)',   // ذهبي خافت
        'rgba(26, 122, 90, 0.4)',    // زمردي
        'rgba(255, 255, 255, 0.15)', // أبيض شفاف
        'rgba(198, 165, 71, 0.8)',   // ذهبي ساطع
    ];

    for (let i = 0; i < particleCount; i++) {
        particles.push({
            x: Math.random() * canvas.width,
            y: Math.random() * canvas.height,
            size: Math.random() * 3 + 0.5,
            speedX: (Math.random() - 0.5) * 0.4,
            speedY: (Math.random() - 0.5) * 0.3 - 0.2, // تصاعد خفيف
            color: colors[Math.floor(Math.random() * colors.length)],
            opacity: Math.random() * 0.8 + 0.2,
            pulse: Math.random() * Math.PI * 2, // نبضة عشوائية
        });
    }

    function animate() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        particles.forEach(p => {
            p.x += p.speedX;
            p.y += p.speedY;
            p.pulse += 0.02;

            // تغيير الحجم نبضياً
            const dynamicSize = p.size + Math.sin(p.pulse) * 0.8;

            // إعادة التدوير
            if (p.y < -10) p.y = canvas.height + 10;
            if (p.x < -10) p.x = canvas.width + 10;
            if (p.x > canvas.width + 10) p.x = -10;

            // رسم الجزيء
            ctx.beginPath();
            ctx.arc(p.x, p.y, Math.max(dynamicSize, 0.5), 0, Math.PI * 2);
            ctx.fillStyle = p.color;
            ctx.fill();

            // توهج خافت حول الجزيئات الكبيرة
            if (p.size > 1.5) {
                ctx.beginPath();
                ctx.arc(p.x, p.y, dynamicSize * 3, 0, Math.PI * 2);
                const glow = ctx.createRadialGradient(p.x, p.y, 0, p.x, p.y, dynamicSize * 3);
                glow.addColorStop(0, 'rgba(198, 165, 71, 0.08)');
                glow.addColorStop(1, 'transparent');
                ctx.fillStyle = glow;
                ctx.fill();
            }
        });

        particleAnimationId = requestAnimationFrame(animate);
    }

    animate();

    // تحديث حجم الكانفاس عند تغيير حجم النافذة
    window.addEventListener('resize', () => {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
    });
}

function stopParticles() {
    if (particleAnimationId) {
        cancelAnimationFrame(particleAnimationId);
        particleAnimationId = null;
    }
}

// =========================================
//  دوال المشهد السينمائي
// =========================================
function showCelebration() {
    const overlay = document.getElementById('celebrationOverlay');
    overlay.classList.add('active');
    document.body.style.overflow = 'hidden';
    initParticles();

    // إغلاق بالضغط على الخلفية (خارج المحتوى)
    overlay.addEventListener('click', (e) => {
        if (e.target === overlay || e.target.tagName === 'CANVAS') {
            closeCelebration();
        }
    });
}

function closeCelebration() {
    const overlay = document.getElementById('celebrationOverlay');
    overlay.classList.remove('active');
    document.body.style.overflow = '';
    stopParticles();
}
