# BAD: รันเป็น root โดย default
FROM alpine:3.20
COPY app.sh /app.sh
RUN chmod +x /app.sh
CMD ["/app.sh"]
