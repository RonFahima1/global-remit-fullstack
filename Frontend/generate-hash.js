const bcrypt = require('bcryptjs');

const password = 'Password123';
const saltRounds = 10;

bcrypt.hash(password, saltRounds, function(err, hash) {
    if (err) {
        console.error('Error generating hash:', err);
        return;
    }
    console.log('Password:', password);
    console.log('Bcrypt Hash:', hash);
}); 