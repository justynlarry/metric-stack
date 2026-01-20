FROM nginx:alpine

# Remove the default symlinks that point to stdout/stderr
RUN rm -f /var/log/nginx/access.log /var/log/nginx/error.log

# Create empty log files that nginx will write to
RUN touch /var/log/nginx/access.log /var/log/nginx/error.log

# Ensure nginx user can write to these files
RUN chown nginx:nginx /var/log/nginx/access.log /var/log/nginx/error.log
