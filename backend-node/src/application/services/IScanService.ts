import type { ScanImageResponseSchema } from '../../domain/schemas/scanSchemas.js';
import type { z } from 'zod';

type ScanImageResponse = z.infer<typeof ScanImageResponseSchema>;

export interface IScanService {
  extractAddressesFromImage(imageBuffer: Buffer): Promise<ScanImageResponse>;
}