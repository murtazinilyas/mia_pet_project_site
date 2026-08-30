// ===== Автогод в футере =====
document.addEventListener('DOMContentLoaded', function () {
  // Инициализация иконок Lucide (если подключены)
  if (window.lucide && typeof window.lucide.createIcons === 'function') {
    lucide.createIcons();
  }

  const yearEl = document.getElementById('year');
  if (yearEl) {
    yearEl.textContent = new Date().getFullYear();
  }

  const consentDate = document.getElementById('consent-date');
  if (consentDate) {
    const d = new Date();
    consentDate.textContent = d.toLocaleDateString('ru-RU', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    });
  }
});

// ===== Мобильное меню =====
document.addEventListener('DOMContentLoaded', function () {
  const burger = document.getElementById('burger');
  const nav = document.getElementById('nav');

  if (burger && nav) {
    burger.addEventListener('click', function () {
      const isOpen = nav.classList.toggle('nav--open');
      burger.classList.toggle('burger--active', isOpen);
    });

    // Закрывать меню при клике по ссылке
    nav.querySelectorAll('a').forEach(function (link) {
      link.addEventListener('click', function () {
        nav.classList.remove('nav--open');
        burger.classList.remove('burger--active');
      });
    });
  }
});

// ===== Маска телефона =====
function formatPhone(value) {
  let digits = value.replace(/\D/g, '');
  if (digits.startsWith('8')) digits = '7' + digits.slice(1);
  if (digits.startsWith('9')) digits = '7' + digits;
  if (!digits.startsWith('7')) digits = '7' + digits;
  digits = digits.slice(0, 11);

  let result = '+7';
  if (digits.length > 1) result += ' (' + digits.slice(1, 4);
  if (digits.length >= 4) result += ') ' + digits.slice(4, 7);
  if (digits.length >= 7) result += '-' + digits.slice(7, 9);
  if (digits.length >= 9) result += '-' + digits.slice(9, 11);
  return result;
}

// ===== Валидация и отправка формы =====
document.addEventListener('DOMContentLoaded', function () {
  const form = document.getElementById('request-form');
  if (!form) return;

  const phoneInput = document.getElementById('phone');

  if (phoneInput) {
    phoneInput.addEventListener('input', function () {
      this.value = formatPhone(this.value);
    });
  }

  // Показ/скрытие поля «Удобное время звонка» в зависимости от выбора
  const callFirst = document.getElementById('call_first');
  const callTimeGroup = document.getElementById('call_time-group');
  const callTimeInput = document.getElementById('call_time');

  function toggleCallTime() {
    if (!callFirst || !callTimeGroup) return;
    if (callFirst.value === 'no') {
      callTimeGroup.classList.add('is-hidden');
      if (callTimeInput) callTimeInput.value = '';
    } else {
      callTimeGroup.classList.remove('is-hidden');
    }
  }

  if (callFirst) {
    toggleCallTime();
    callFirst.addEventListener('change', toggleCallTime);
  }

  function setError(name, message) {
    const errEl = form.querySelector('[data-error="' + name + '"]');
    const input = form.querySelector('[name="' + name + '"]');
    if (errEl) errEl.textContent = message;
    if (input && input.classList) {
      if (message) input.classList.add('is-invalid');
      else input.classList.remove('is-invalid');
    }
  }

  function validateField(field) {
    const name = field.name;
    const value = field.value.trim();

    if (name === 'name') {
      if (!value) {
        setError('name', 'Пожалуйста, укажите ваше имя.');
        return false;
      }
      if (value.length < 2) {
        setError('name', 'Имя должно содержать минимум 2 символа.');
        return false;
      }
      setError('name', '');
      return true;
    }

    if (name === 'phone') {
      if (!value) {
        setError('phone', 'Пожалуйста, укажите номер телефона.');
        return false;
      }
      if (value.replace(/\D/g, '').length < 11) {
        setError('phone', 'Введите корректный номер телефона.');
        return false;
      }
      setError('phone', '');
      return true;
    }

    if (name === 'agreement') {
      if (!field.checked) {
        setError('agreement', 'Необходимо согласие на обработку персональных данных.');
        return false;
      }
      setError('agreement', '');
      return true;
    }

    return true;
  }

  // Валидация по мере ввода
  form.querySelectorAll('input, select, textarea').forEach(function (el) {
    el.addEventListener('blur', function () {
      if (this.name) validateField(this);
    });
  });

  form.addEventListener('submit', function (e) {
    e.preventDefault();

    let isValid = true;
    form.querySelectorAll('input, select, textarea').forEach(function (el) {
      if (el.name) {
        if (!validateField(el)) isValid = false;
      }
    });

    // Соглашение (checkbox)
    const agreement = document.getElementById('agreement');
    if (agreement && !validateField(agreement)) isValid = false;

    if (!isValid) {
      const firstInvalid = form.querySelector('.is-invalid');
      if (firstInvalid) firstInvalid.focus();
      return;
    }

    // Формируем данные заявки
    const data = {
      name: form.querySelector('[name="name"]').value.trim(),
      phone: form.querySelector('[name="phone"]').value.trim(),
      city: 'Бугульма',
      service: form.querySelector('[name="service"]').value,
      address: form.querySelector('[name="address"]').value.trim(),
      call_time: form.querySelector('[name="call_time"]').value.trim(),
      call_first: form.querySelector('[name="call_first"]').value,
      message: form.querySelector('[name="message"]').value.trim(),
      agreement: form.querySelector('[name="agreement"]').checked
    };

    // Отправляем заявку на сервер (server.py -> Telegram)
    const submitBtn = form.querySelector('button[type="submit"]');
    const success = document.getElementById('form-success');

    if (submitBtn) {
      submitBtn.disabled = true;
      submitBtn.textContent = 'Отправка...';
    }

    fetch('/api/request', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data)
    })
      .then(function (res) {
        return res.json();
      })
      .then(function (result) {
        if (result.ok) {
          form.reset();
          if (success) success.hidden = false;
          if (success) success.scrollIntoView({ behavior: 'smooth', block: 'center' });
        } else {
          alert('Не удалось отправить заявку: ' + (result.error || 'Неизвестная ошибка'));
        }
      })
      .catch(function (err) {
        console.error('Ошибка отправки:', err);
        alert('Не удалось отправить заявку. Проверьте подключение к интернету.');
      })
      .finally(function () {
        if (submitBtn) {
          submitBtn.disabled = false;
          submitBtn.textContent = 'Отправить заявку';
        }
      });
  });
});