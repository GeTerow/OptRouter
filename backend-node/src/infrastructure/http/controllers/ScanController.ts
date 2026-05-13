import type { Request, Response } from 'express';
import type { ScanImageUseCase } from '../../../application/usecases/ScanImageUseCase.js';

export class ScanController {
  constructor(private scanImageUseCase: ScanImageUseCase) {}

  async handle(req: Request, res: Response): Promise<Response> {
    if (!req.file) {
      return res.status(400).json({ message: 'Nenhuma imagem foi enviada.' });
    }

    try {
      const result = await this.scanImageUseCase.execute(req.file.buffer);
      return res.status(200).json(result);
    } catch (error) {
      console.error(error);
      const errorMessage = error instanceof Error ? error.message : 'Erro interno no servidor.';
      return res.status(500).json({ message: errorMessage });
    }
  }
}