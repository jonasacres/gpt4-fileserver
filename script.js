document.getElementById('upload').addEventListener('click', function() {
    var fileInput = document.getElementById('file');
    var file = fileInput.files[0];
    if (!file) {
        alert('Please choose a file first!');
        return;
    }

    var progressBar = document.getElementById('progress-bar');
    var progressBarDiv = progressBar.querySelector('div');
    var uploadCompleteLabel = document.getElementById('upload-complete');
    var uploadStatus = document.getElementById('upload-status');
    var tokenField = document.getElementById('token');
    var tokenValue = tokenField.value;
    var startTime;

    // Remove error class from token field
    tokenField.classList.remove('error');

    progressBarDiv.style.width = '0%';
    progressBarDiv.textContent = '';
    // progressBar.className = '';
    uploadCompleteLabel.style.display = 'none';
    uploadStatus.textContent = 'Authorizing...';

    var authRequest = new XMLHttpRequest();
    authRequest.open('POST', '/auth', true);

    var formData = new FormData();
    formData.append('filename', file.name);
    formData.append('filesize', file.size);
    formData.append('token', tokenValue);

    authRequest.addEventListener('load', function() {
        if (authRequest.status === 200) {
            var authResponse = JSON.parse(authRequest.responseText);
            var auth = authResponse.auth;

            var uploadRequest = new XMLHttpRequest();
            uploadRequest.upload.addEventListener('progress', function(e) {
                if (!startTime) {
                    startTime = Date.now();
                }

                var percent = Math.round((e.loaded / e.total) * 100);
                progressBarDiv.style.width = percent + '%';

                var timeElapsed = Date.now() - startTime;
                var speed = Math.round(e.loaded / timeElapsed * 1000 / (1024 * 1024));
                var estimatedTime = Math.round((e.total - e.loaded) / (speed * 1024 * 1024));

                uploadStatus.textContent = 'Speed: ' + speed + ' MiB/s. ' + percent + '% complete.';
                progressBarDiv.textContent = percent + '%';

                if (percent === 100) {
                    uploadStatus.textContent = 'Finalizing...';
                }
            });

            uploadRequest.addEventListener('load', function() {
                if (uploadRequest.status === 200) {
                    uploadCompleteLabel.style.display = 'block';
                    uploadStatus.textContent = '';
                } else if (uploadRequest.status == 403) {
                    // Add error class to token field and focus on it
                    tokenField.classList.add('error');
                    tokenField.focus();
                    uploadStatus.textContent = 'Authentication error';
                }
            });

            uploadRequest.open('POST', '/upload', true);
            formData.append('auth', auth);
            formData.append('file', file);
            uploadRequest.send(formData);
        } else if (authRequest.status == 403) {
            // Add error class to token field and focus on it
            tokenField.classList.add('error');
            tokenField.focus();
            uploadStatus.textContent = 'Wrong password';
        }
    });

    authRequest.send(formData);
});
