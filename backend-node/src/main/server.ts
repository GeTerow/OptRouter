import express from 'express';
import type { Express, Request, Response } from 'express';
import 'dotenv/config';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { router } from '../infrastructure/http/routes.js';

const app: Express = express();
const PORT = process.env.PORT || 3008;
const corsOrigins = (process.env.CORS_ORIGIN || process.env.FRONTEND_ORIGIN || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

// Headers de segurança HTTP para proteger contra vulnerabilidades conhecidas
app.use(helmet());
app.use(
  cors({
    origin: corsOrigins.length > 0 ? corsOrigins : true,
  })
);

const limiter = rateLimit({
	windowMs: 15 * 60 * 1000, // Janela de 15 minutos
	max: 100,
	standardHeaders: true,
	legacyHeaders: false,
  message: 'Muitas requisições enviadas deste IP, por favor, tente novamente após 15 minutos.'
});
app.use(limiter);

app.use(express.json());
app.use(router);

app.get('/ping', (req: Request, res: Response) => {
  res.json({ message: 'pong' });
});

app.listen(PORT, () => {
    console.log(`Ta rodando na porta ${PORT}`);
});
