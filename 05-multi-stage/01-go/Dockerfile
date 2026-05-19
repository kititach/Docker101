# Stage 1: Build — golang image มีทุกอย่างที่ต้องการ compile
FROM golang:1.22-alpine AS builder
WORKDIR /src
COPY go.mod .
COPY main.go .
# CGO_ENABLED=0: static binary ไม่พึ่ง C library
# -ldflags="-s -w": ตัด debug symbols และ DWARF → binary เล็กลง ~30%
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /app .

# Stage 2: Runtime — scratch คือ empty image ไม่มีอะไรเลย
FROM scratch
COPY --from=builder /app /app
EXPOSE 8080
ENTRYPOINT ["/app"]
