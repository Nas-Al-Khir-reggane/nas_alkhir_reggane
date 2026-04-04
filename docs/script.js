document.addEventListener('DOMContentLoaded', async () => {
    
    const REPO_OWNER = 'ahmed-majija';
    const REPO_NAME = 'nas_alkhir_reggane';
    const API_URL = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest`;

    const versionInfo = document.getElementById('versionInfo');
    const loadingSpinner = document.getElementById('loading-spinner');
    const errorMsg = document.getElementById('error-message');
    
    // زر التحميل الموحد
    const mainDownloadBtn = document.getElementById('btn-main-download');

    try {
        const response = await fetch(API_URL);
        
        if (!response.ok) {
            throw new Error('لا يوجد إصدارات عامة متاحة بعد.');
        }

        const data = await response.json();
        
        // تحديث النص لمعرّف الإصدار
        versionInfo.textContent = `الإصدار الأحدث: ${data.tag_name} | صدر في: ${new Date(data.published_at).toLocaleDateString('ar-EG')}`;
        versionInfo.style.color = '#2ed573'; // لون أخضر للنجاح

        let foundAsset = false;

        // البحث في ملفات الإصدار المرفوعة عن أي ملف APK
        if (data.assets && data.assets.length > 0) {
            for (const asset of data.assets) {
                if (asset.name.toLowerCase().endsWith('.apk')) {
                    mainDownloadBtn.href = asset.browser_download_url;
                    mainDownloadBtn.classList.remove('disabled');
                    mainDownloadBtn.style.background = 'linear-gradient(135deg, var(--primary-light), var(--primary))'; // تفعيل لوني قوي
                    foundAsset = true;
                    break; // وجدنا التطبيق، لا داعي للبحث أكثر
                }
            }
        }

        // إخفاء مؤشر التحميل
        loadingSpinner.style.display = 'none';

        // إذا لم يتم العثور على التطبيق
        if (!foundAsset) {
            errorMsg.style.display = 'block';
            errorMsg.querySelector('span').textContent = 'الإصدار موجود، لكن لم يتم تثبيت النسخة القابلة للتحميل بداخله بعد.';
        }

    } catch (error) {
        // حالة الخطأ
        loadingSpinner.style.display = 'none';
        errorMsg.style.display = 'block';
        
        versionInfo.textContent = 'في انتظار أول إصدار (Release)';
        versionInfo.style.color = 'rgba(255, 255, 255, 0.5)';
        
        console.error("خطأ في جلب الإصدار:", error);
    }
});
